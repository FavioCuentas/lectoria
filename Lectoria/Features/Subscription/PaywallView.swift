import SwiftUI
import StoreKit

// MARK: - PlanSelection

public enum PlanSelection: String, CaseIterable, Identifiable, Sendable {
    case yearly
    case lifetime

    public var id: String { rawValue }
}

// MARK: - PaywallView

/// Vista comercial y transparente para la suscripción y planes de Lectoría según el diseño oficial.
///
/// Soporta los niveles de acceso requeridos por la especificación:
/// - `yearly`: Suscripción anual Premium ($4.99/año con 7 días de prueba).
/// - `lifetime`: Licencia de por vida ($19.99 pago único).
/// - `institutional`: Acceso patrocinado por universidades/organizaciones.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    @State private var products: [StoreKit.Product] = []
    @State private var selectedPlan: PlanSelection = .yearly
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showInstitutionalAuth = false
    @State private var showManageSubscriptions = false

    // Color del sistema de marca Terracota/Naranja de Lectoría
    private let brandOrange = Color(red: 0.85, green: 0.42, blue: 0.15)

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: AppSpacing.md) {
                        // 1. Encabezado con botón de cierre
                        headerSection(theme: theme)

                        // 2. Ilustración de Mascota Oficial
                        mascotSection

                        // 3. Mensaje Principal (Título y Subtítulo)
                        headlineSection(theme: theme)

                        // 4. Bloque de Beneficios Premium
                        benefitsSection(theme: theme)

                        // 5. Selector de Planes (Anual / Por vida)
                        planSelectorSection(theme: theme)

                        // 6. Tarjeta de Acceso Institucional
                        institutionalCardSection(theme: theme)

                        // 7. Acciones Secundarias (Restaurar y Administrar)
                        secondaryActionsSection(theme: theme)

                        // 8. Revelaciones Contractuales y Legales
                        disclosuresSection(theme: theme)

                        // Espaciador inferior para evitar que el contenido sea tapado por el CTA fijo
                        Color.clear.frame(height: 140)
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, AppSpacing.sm)
                }
                .background(AppColor.background(for: theme))

                // 9. CTA Fijo Inferior con Safe Area Bottom
                bottomCTASection(theme: theme)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showInstitutionalAuth) {
                InstitutionalAuthView {
                    dismiss()
                }
            }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
            .task {
                await loadStoreKitProducts()
            }
            .onAppear {
                let isPremium = dependencies.subscriptionService.hasActiveSubscription
                dependencies.analyticsService.track(.paywallViewed, properties: [
                    "current_plan": isPremium ? "premium" : "free"
                ])
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

    // MARK: - 1. Encabezado

    private func headerSection(theme: AppTheme) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Cerrar planes")

            Spacer()

            Text("Elige tu plan")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColor.textPrimary(for: theme))

            Spacer()

            // Balanceador horizontal transparente
            Color.clear
                .frame(width: 32, height: 32)
        }
        .padding(.top, AppSpacing.xs)
    }

    // MARK: - 2. Mascota Ilustración Oficial

    private var mascotSection: some View {
        Image("lectoriaPremiumMascot")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .shadow(color: brandOrange.opacity(0.25), radius: 8, x: 0, y: 4)
            .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - 3. Mensaje Principal

    private func headlineSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            Text("Lee, estudia y organiza sin límites")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(AppColor.textPrimary(for: theme))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("Desbloquea todas las herramientas Premium de Lectoría.")
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary(for: theme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    // MARK: - 4. Bloque de Beneficios Premium

    private func benefitsSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            benefitRow(
                icon: "book.fill",
                title: "Lectura y biblioteca sin límites.",
                theme: theme
            )

            benefitRow(
                icon: "text.badge.checkmark",
                title: "Notas, resaltados y herramientas de estudio.",
                theme: theme
            )

            benefitRow(
                icon: "speaker.wave.2.fill",
                title: "Texto a voz y funciones avanzadas de lectura.",
                theme: theme
            )

            benefitRow(
                icon: "laptopcomputer.and.iphone",
                title: "Uso en hasta 3 dispositivos.",
                theme: theme
            )
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surfaceSecondary(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    private func benefitRow(icon: String, title: String, theme: AppTheme) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColor.textSecondary(for: theme))
                .frame(width: 22, height: 22)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColor.textPrimary(for: theme))
        }
    }

    // MARK: - 5. Selector de Planes

    private func planSelectorSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.md) {
            // Tarjeta 1: Premium Anual (Recomendado)
            yearlyPlanCard(theme: theme)

            // Tarjeta 2: Premium de por vida
            lifetimePlanCard(theme: theme)
        }
        .padding(.top, AppSpacing.xs)
    }

    /// Producto anual a la venta: precio Fundador mientras esté publicado; si no, el anual regular.
    private var annualStoreProduct: StoreKit.Product? {
        products.first(where: { $0.id == StoreKitSubscriptionService.founderProductID })
            ?? products.first(where: { $0.id == StoreKitSubscriptionService.yearlyProductID })
    }

    private var lifetimeStoreProduct: StoreKit.Product? {
        products.first(where: { $0.id == StoreKitSubscriptionService.lifetimeProductID })
    }

    private func yearlyPlanCard(theme: AppTheme) -> some View {
        let isSelected = selectedPlan == .yearly
        let yearlyProduct = annualStoreProduct
        let priceText = yearlyProduct?.displayPrice ?? "USD 4,99"

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPlan = .yearly
            }
        } label: {
            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Premium Anual")
                                .font(.system(size: 17, weight: .bold, design: .serif))
                                .foregroundStyle(AppColor.textPrimary(for: theme))

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(priceText)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppColor.textPrimary(for: theme))

                                Text("al año")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(AppColor.textSecondary(for: theme))
                            }
                        }

                        Spacer()

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(isSelected ? brandOrange : AppColor.textTertiary(for: theme))
                    }

                    Text("7 días gratis, luego \(priceText) al año.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AppColor.textSecondary(for: theme))
                        .padding(.top, 2)
                }
                .padding(AppSpacing.md)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(isSelected ? brandOrange : AppColor.border(for: theme), lineWidth: isSelected ? 2 : 1)
                )

                // Badge "RECOMENDADO" superpuesto en el borde superior
                Text("RECOMENDADO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(brandOrange)
                    .clipShape(Capsule())
                    .offset(x: 16, y: -10)
            }
        }
        .buttonStyle(.plain)
    }

    private func lifetimePlanCard(theme: AppTheme) -> some View {
        let isSelected = selectedPlan == .lifetime
        let lifetimeProduct = lifetimeStoreProduct
        let priceText = lifetimeProduct?.displayPrice ?? "USD 19,99"

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedPlan = .lifetime
            }
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium de por vida")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(AppColor.textPrimary(for: theme))

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(priceText)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(AppColor.textPrimary(for: theme))

                            Text("pago único")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(AppColor.textSecondary(for: theme))
                        }
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isSelected ? brandOrange : AppColor.textTertiary(for: theme))
                }

                Text("Acceso permanente a las funciones principales.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppColor.textSecondary(for: theme))
                    .padding(.top, 2)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(isSelected ? brandOrange : AppColor.border(for: theme), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 6. Acceso Institucional

    private func institutionalCardSection(theme: AppTheme) -> some View {
        Button {
            showInstitutionalAuth = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(brandOrange.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(brandOrange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("¿Perteneces a una institución educativa?", comment: "Institutional prompt title")
                        .font(.system(size: 13, weight: .bold))
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
            .padding(AppSpacing.sm)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .stroke(AppColor.border(for: theme), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 7. Acciones Secundarias

    private func secondaryActionsSection(theme: AppTheme) -> some View {
        HStack(spacing: AppSpacing.md) {
            Button(String(localized: "Restaurar compras", comment: "Paywall: restore action")) {
                performRestore()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(brandOrange)

            Text("•")
                .font(.system(size: 12))
                .foregroundStyle(AppColor.textTertiary(for: theme))

            Button(String(localized: "Administrar suscripción", comment: "Paywall: manage action")) {
                showManageSubscriptions = true
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(brandOrange)
        }
        .padding(.top, AppSpacing.xs)
    }

    // MARK: - 8. Legales y Divulgaciones

    private func disclosuresSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Text("Lectoría Lifetime concede acceso permanente a las funciones principales del lector incluidas en esta modalidad, durante la vida operativa del producto y mientras sea compatible con los dispositivos y sistemas soportados. No incluye servicios de terceros, almacenamiento adicional, inteligencia artificial externa ni productos futuros independientes.",
                 comment: "Paywall: lifetime disclosure contract")
                .font(.system(size: 10))
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .multilineTextAlignment(.center)

            Text("Suscripción auto-renovable. Al finalizar los 7 días de prueba gratuita, el cobro se realizará a tu cuenta de Apple ID. La suscripción se renueva automáticamente a menos que se cancele al menos 24 horas antes del final del período actual.",
                 comment: "Paywall: auto renewal disclosure")
                .font(.system(size: 10))
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.xs)
    }

    // MARK: - 9. Bottom CTA

    private func bottomCTASection(theme: AppTheme) -> some View {
        let yearlyProduct = annualStoreProduct
        let lifetimeProduct = lifetimeStoreProduct
        let yearlyPrice = yearlyProduct?.displayPrice ?? "USD 4,99"
        let lifetimePrice = lifetimeProduct?.displayPrice ?? "USD 19,99"

        return VStack(spacing: AppSpacing.xs) {
            // Texto descriptivo sobre el botón
            if selectedPlan == .yearly {
                Text("7 días gratis. Después, \(yearlyPrice) al año.")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary(for: theme))
            } else {
                Text("\(lifetimePrice) pago único.")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppColor.textPrimary(for: theme))
            }

            // Botón Principal CTA
            Button {
                let targetProduct = selectedPlan == .yearly ? yearlyProduct : lifetimeProduct
                if let targetProduct {
                    performPurchase(targetProduct)
                } else {
                    errorMessage = String(localized: "No se pudieron cargar los productos de la App Store. Comprueba tu conexión e inténtalo de nuevo.", comment: "Paywall: products unavailable error")
                    showErrorAlert = true
                    Task { await loadStoreKitProducts() }
                }
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(selectedPlan == .yearly ? "Comenzar prueba gratuita" : "Comprar acceso de por vida")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .disabled(isLoading)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(brandOrange)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Links legales inferiores
            VStack(spacing: 3) {
                Text("DETALLES DE COMPRA Y RENOVACIÓN")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppColor.textTertiary(for: theme))

                HStack(spacing: AppSpacing.sm) {
                    Button("Términos de servicio") {
                        if let url = URL(string: "https://lectoria.app/terms") { openURL(url) }
                    }
                    Text("•")
                    Button("Política de privacidad") {
                        if let url = URL(string: "https://lectoria.app/privacy") { openURL(url) }
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColor.textSecondary(for: theme))
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, AppSpacing.screenHorizontal)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
        .background(
            AppColor.surface(for: theme)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: -4)
        )
    }

    // MARK: - Logic Actions

    private func loadStoreKitProducts() async {
        isLoading = true
        do {
            let loaded = try await dependencies.subscriptionService.loadProducts()
            await MainActor.run {
                self.products = loaded.sorted(by: { $0.price < $1.price })
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

}

// MARK: - Preview

#Preview("Paywall") {
    let themeManager = ThemeManager()
    PaywallView()
        .environment(themeManager)
        .environment(AppDependencies.preview)
}
