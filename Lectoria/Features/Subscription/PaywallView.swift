import SwiftUI
import StoreKit

// MARK: - PaywallView

/// Vista comercial y transparente para la suscripción y planes de Lectoria según la especificación maestra.
///
/// Soporta los niveles de acceso requeridos por la especificación:
/// - `free`: Plan gratuito con límites.
/// - `premium_founder`: Suscripción anual Fundador ($4.99/año, 1.000 cupos).
/// - `premium_regular`: Suscripción anual Regular ($9.99/año).
/// - `lifetime`: Licencia de por vida ($19.99 pago único, 250 cupos).
/// - `institutional`: Acceso patrocinado por universidades/organizaciones.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    @State private var products: [StoreKit.Product] = []
    @State private var selectedProduct: StoreKit.Product?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showInstitutionalAuth = false
    @State private var showManageSubscriptions = false

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Encabezado con gradiente premium
                    headerView(theme: theme)

                    // Resumen de beneficios Premium
                    benefitsSection(theme: theme)

                    // Banner de Prueba Gratuita (7 días)
                    trialBannerView(theme: theme)

                    // Sección de compra (Precios reales de StoreKit 2)
                    if isLoading && products.isEmpty {
                        ProgressView()
                            .padding(.vertical, AppSpacing.xl)
                    } else if !products.isEmpty {
                        pricingSection(theme: theme)
                    } else {
                        // Precios de referencia oficiales (Simulador / Fallback)
                        fallbackPricingSection(theme: theme)
                    }

                    // Enlace a Acceso Institucional
                    institutionalLinkSection(theme: theme)

                    // Enlaces legales, desgloses y restauración
                    legalSection(theme: theme)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColor.background(for: theme))
            .onAppear {
                let isPremium = dependencies.subscriptionService.hasActiveSubscription
                dependencies.analyticsService.track(.paywallViewed, properties: [
                    "current_plan": isPremium ? "premium" : "free"
                ])
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "Cerrar", comment: "Paywall: close button")) {
                        dismiss()
                    }
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showInstitutionalAuth) {
                InstitutionalAuthView {
                    dismiss()
                }
            }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
            .task {
                await loadStoreKitProducts()
            }
            .alert(
                String(localized: "Error", comment: "Alert title: error"),
                isPresented: $showErrorAlert
            ) {
                Button(String(localized: "Aceptar", comment: "Alert action: ok"), role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Header

    private func headerView(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.accent(for: theme), Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, AppSpacing.xs)

            Text("Lectoria Premium")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(AppColor.textPrimary(for: theme))

            Text("Elige el plan ideal para tu lectura y estudio académico.",
                 comment: "Paywall: subtitle description")
                .font(AppTypography.subtitle)
                .foregroundStyle(AppColor.textSecondary(for: theme))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Trial Banner

    private func trialBannerView(theme: AppTheme) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Prueba Gratuita de 7 Días Incluida", comment: "Trial banner title")
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                Text("Prueba todas las funciones Premium sin compromiso. Cancela cuando quieras en App Store.", comment: "Trial banner subtitle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
            }
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Benefits

    private func benefitsSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            benefitRow(
                icon: "doc.badge.plus",
                title: "Documentos Ilimitados",
                desc: "Importa archivos EPUB, PDF, PPTX, TXT y Markdown sin cuota de biblioteca.",
                theme: theme
            )

            benefitRow(
                icon: "pencil.and.outline",
                title: "Destacados y Notas Ilimitadas",
                desc: "Organiza tus lecturas por categorías de estudio académicas sin restricciones.",
                theme: theme
            )

            benefitRow(
                icon: "brain.head.profile",
                title: "IA y Traducción 100% Local",
                desc: "Explicaciones, resúmenes y traducción procesados exclusivamente en tu iPhone sin enviar datos a servidores.",
                theme: theme
            )

            benefitRow(
                icon: "laptopcomputer.and.iphone",
                title: "Hasta 3 Dispositivos Simultáneos",
                desc: "Usa tu suscripción en hasta 3 dispositivos asociados a tu cuenta personal.",
                theme: theme
            )
        }
        .padding(AppSpacing.lg)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private func benefitRow(icon: String, title: String, desc: String, theme: AppTheme) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AppColor.accent(for: theme))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                Text(desc)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                    .lineLimit(nil)
            }
        }
    }

    // MARK: - Pricing Section (StoreKit 2)

    private func pricingSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(products) { product in
                let isSelected = selectedProduct?.id == product.id
                let isLifetime = product.id.contains("lifetime")
                let isFounder = product.id.contains("founder")

                Button {
                    selectedProduct = product
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            HStack(spacing: AppSpacing.xs) {
                                Text(product.displayName)
                                    .font(AppTypography.bodyBold)
                                    .foregroundStyle(AppColor.textPrimary(for: theme))

                                if isLifetime {
                                    Text("Pago único • 250 cupos", comment: "Badge lifetime")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, AppSpacing.xs)
                                        .padding(.vertical, 2)
                                        .background(AppColor.accent(for: theme))
                                        .clipShape(Capsule())
                                } else if isFounder {
                                    Text("Oferta Fundador • 1.000 cupos", comment: "Badge founder")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, AppSpacing.xs)
                                        .padding(.vertical, 2)
                                        .background(Color.orange)
                                        .clipShape(Capsule())
                                }
                            }

                            Text(product.description)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(product.displayPrice)
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColor.textPrimary(for: theme))

                            if !isLifetime {
                                Text("/ año", comment: "Yearly period tag")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.sm)
                            .stroke(
                                isSelected ? AppColor.accent(for: theme) : AppColor.accent(for: theme).opacity(0.15),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .background(AppColor.surface(for: theme).opacity(isSelected ? 0.5 : 0.0))
                }
                .buttonStyle(.plain)
            }

            purchaseButton(theme: theme)
        }
    }

    private func fallbackPricingSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.md) {
            // Opción 1: Premium Fundador ($4.99/año)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("Premium Fundador")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColor.textPrimary(for: theme))

                            Text("Primeros 1.000 compradores")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        Text("Acceso ilimitado por 12 meses con 7 días de prueba")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }
                    Spacer()
                    Text("USD $4.99 / año")
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .stroke(AppColor.accent(for: theme), lineWidth: 2)
            )
            .background(AppColor.surface(for: theme))

            // Opción 2: Premium Lifetime ($19.99)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("Premium De por Vida")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColor.textPrimary(for: theme))

                            Text("Pago único • 250 cupos")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 2)
                                .background(AppColor.accent(for: theme))
                                .clipShape(Capsule())
                        }
                        Text("Licencia permanente para funciones principales")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }
                    Spacer()
                    Text("USD $19.99")
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                }
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

            Button(String(localized: "Simular suscripción Premium", comment: "Paywall: simulate action")) {
                simulatePremiumPurchase()
            }
            .font(AppTypography.bodyBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppColor.accent(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        }
    }

    private func institutionalLinkSection(theme: AppTheme) -> some View {
        Button {
            showInstitutionalAuth = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.accent(for: theme))

                VStack(alignment: .leading, spacing: 2) {
                    Text("¿Perteneces a una institución educativa?", comment: "Institutional prompt title")
                        .font(AppTypography.caption.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    Text("Accede gratis con tu correo o código institucional", comment: "Institutional prompt subtitle")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                }
                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColor.textTertiary(for: theme))
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .strokeBorder(AppColor.accent(for: theme).opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func purchaseButton(theme: AppTheme) -> some View {
        Button {
            if let selectedProduct {
                performPurchase(selectedProduct)
            }
        } label: {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(String(localized: "Iniciar Prueba Gratuita de 7 Días", comment: "Paywall: start trial button"))
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(.white)
            }
        }
        .disabled(selectedProduct == nil || isLoading)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(selectedProduct == nil ? AppColor.textTertiary(for: theme) : AppColor.accent(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        .padding(.top, AppSpacing.xs)
    }

    // MARK: - Legal & Restore

    private func legalSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                Button(String(localized: "Restaurar compras", comment: "Paywall: restore action")) {
                    performRestore()
                }
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColor.accent(for: theme))

                Text("•")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary(for: theme))

                Button(String(localized: "Administrar suscripción", comment: "Paywall: manage action")) {
                    showManageSubscriptions = true
                }
                .font(AppTypography.caption.weight(.semibold))
                .foregroundStyle(AppColor.accent(for: theme))
            }

            // Texto contractual obligatorio para Lifetime
            Text("Lectoría Lifetime concede acceso permanente a las funciones principales del lector incluidas en esta modalidad, durante la vida operativa del producto y mientras sea compatible con los dispositivos y sistemas soportados. No incluye servicios de terceros, almacenamiento adicional, inteligencia artificial externa ni productos futuros independientes.",
                 comment: "Paywall: lifetime disclosure contract")
                .font(.system(size: 10))
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xs)

            // Divulgación legal de suscripciones auto-renovables
            Text("Suscripción auto-renovable. Al finalizar los 7 días de prueba gratuita, el cobro se realizará a tu cuenta de Apple ID. La suscripción se renueva automáticamente a menos que se cancele al menos 24 horas antes del final del período actual.",
                 comment: "Paywall: auto renewal disclosure")
                .font(.system(size: 10))
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .multilineTextAlignment(.center)

            HStack(spacing: AppSpacing.md) {
                Button(String(localized: "Términos de servicio", comment: "Legal: terms")) {
                    if let url = URL(string: "https://lectoria.app/terms") { openURL(url) }
                }
                Text("•")
                Button(String(localized: "Política de privacidad", comment: "Legal: privacy")) {
                    if let url = URL(string: "https://lectoria.app/privacy") { openURL(url) }
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(AppColor.textSecondary(for: theme))
        }
        .padding(.vertical, AppSpacing.md)
    }

    // MARK: - Logic Actions

    private func loadStoreKitProducts() async {
        isLoading = true
        do {
            let loaded = try await dependencies.subscriptionService.loadProducts()
            await MainActor.run {
                self.products = loaded.sorted(by: { $0.price < $1.price })
                self.selectedProduct = self.products.first
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func performPurchase(_ product: StoreKit.Product) {
        isLoading = true
        Task {
            do {
                let transaction = try await dependencies.subscriptionService.purchase(product)
                if transaction != nil {
                    dependencies.analyticsService.track(.purchaseCompleted, properties: [
                        "product_id": product.id,
                        "price": product.displayPrice
                    ])
                }
                await MainActor.run {
                    self.isLoading = false
                    if transaction != nil {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                    self.isLoading = false
                }
            }
        }
    }

    private func performRestore() {
        isLoading = true
        Task {
            do {
                try await dependencies.subscriptionService.restorePurchases()
                await MainActor.run {
                    self.isLoading = false
                    if dependencies.subscriptionService.hasActiveSubscription {
                        dismiss()
                    } else {
                        self.errorMessage = String(localized: "No se encontraron compras anteriores válidas.", comment: "Paywall: error message restore")
                        self.showErrorAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                    self.isLoading = false
                }
            }
        }
    }

    private func simulatePremiumPurchase() {
        isLoading = true
        Task {
            if let mock = dependencies.subscriptionService as? MockSubscriptionService {
                mock.hasActiveSubscription = true
                mock.activeEntitlement = SubscriptionEntitlement(
                    productID: "com.lectoria.premium.yearly",
                    status: "active"
                )
            }
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                self.isLoading = false
                dismiss()
            }
        }
    }
}

// MARK: - Preview

#Preview("Paywall") {
    let themeManager = ThemeManager()
    PaywallView()
        .environment(themeManager)
        .environment(AppDependencies.preview)
}
