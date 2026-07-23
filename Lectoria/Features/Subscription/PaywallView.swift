import SwiftUI
import StoreKit

// MARK: - PaywallView

/// Vista comercial y honesta para la suscripción y planes de Lectoria.
///
/// Soporta los 4 niveles de acceso requeridos por la especificación:
/// - `free`: Plan gratuito con límites.
/// - `premium_annual`: Suscripción anual (~USD 5/año).
/// - `premium_lifetime`: Licencia de por vida (~USD 20 pago único).
/// - `institutional`: Acceso ilimitado patrocinado por universidades/escuelas.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    @State private var products: [StoreKit.Product] = []
    @State private var selectedProduct: StoreKit.Product?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showInstitutionalAuth = false

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Encabezado con gradiente premium
                    headerView(theme: theme)

                    // Beneficios de los Planes Premium & Institucionales
                    benefitsSection(theme: theme)

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

                    // Enlaces legales y restauración
                    legalSection(theme: theme)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColor.background(for: theme))
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
                title: "IA 100% Local en Dispositivo",
                desc: "Explicaciones, resúmenes y traducción procesados exclusivamente en tu iPhone sin servidores externos.",
                theme: theme
            )

            benefitRow(
                icon: "arrow.triangle.2.circlepath",
                title: "Sincronización Offline-First",
                desc: "Respaldo automático de tu progreso y anotaciones en todos tus dispositivos.",
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
                let isYearly = product.id.contains("yearly")

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
                                    Text("Pago único")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, AppSpacing.xs)
                                        .padding(.vertical, 2)
                                        .background(AppColor.accent(for: theme))
                                        .clipShape(Capsule())
                                } else if isYearly {
                                    Text("Mejor Valor (~$5/año)")
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

                        Text(product.displayPrice)
                            .font(AppTypography.body)
                            .fontWeight(.bold)
                            .foregroundStyle(AppColor.textPrimary(for: theme))
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
            // Opción 1: Premium Anual (~USD 5/año)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("Premium Anual")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColor.textPrimary(for: theme))

                            Text("Popular (~$5/año)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                        Text("Acceso ilimitado por 12 meses")
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

            // Opción 2: Premium de por vida (~USD 20)
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("Premium De por Vida")
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColor.textPrimary(for: theme))

                            Text("Pago único")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 2)
                                .background(AppColor.accent(for: theme))
                                .clipShape(Capsule())
                        }
                        Text("Licencia permanente sin renovaciones")
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
                    Text("¿Perteneces a una institución educativa?")
                        .font(AppTypography.caption.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    Text("Accede gratis con tu correo o código institucional", comment: "Institutional link subtitle")
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
                Text(String(localized: "Suscribirse ahora", comment: "Paywall: subscribe button"))
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
            Button(String(localized: "Restaurar compras", comment: "Paywall: restore action")) {
                performRestore()
            }
            .font(AppTypography.caption.weight(.semibold))
            .foregroundStyle(AppColor.accent(for: theme))

            Text("Suscripción auto-renovable (o pago único). El cobro se realizará a tu cuenta de Apple ID al confirmar la compra. Puedes administrar o cancelar tus suscripciones desde los ajustes de tu cuenta de App Store.",
                 comment: "Paywall: subscription disclosure")
                .font(.system(size: 10))
                .foregroundStyle(AppColor.textTertiary(for: theme))
                .multilineTextAlignment(.center)

            HStack(spacing: AppSpacing.md) {
                Link(String(localized: "Términos de servicio", comment: "Legal: terms"), destination: URL(string: "https://lectoria.app/terms")!)
                Text("•")
                Link(String(localized: "Política de privacidad", comment: "Legal: privacy"), destination: URL(string: "https://lectoria.app/privacy")!)
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
