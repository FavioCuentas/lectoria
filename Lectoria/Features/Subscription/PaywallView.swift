import SwiftUI
import StoreKit

// MARK: - PaywallView

/// Vista premium y honesta para la suscripción de Lectoria.
///
/// Muestra los beneficios del plan Premium, carga y muestra los precios localizados
/// directamente desde StoreKit 2 y permite comprar o restaurar compras.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    @State private var products: [StoreKit.Product] = []
    @State private var selectedProduct: StoreKit.Product?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Encabezado con gradiente premium
                    headerView(theme: theme)

                    // Beneficios Premium
                    benefitsSection(theme: theme)

                    // Sección de compra (Precios de StoreKit)
                    if isLoading && products.isEmpty {
                        ProgressView()
                            .padding(.vertical, AppSpacing.xl)
                    } else if !products.isEmpty {
                        pricingSection(theme: theme)
                    } else {
                        // Si no hay productos de StoreKit (por ejemplo, en simulador sin configuración)
                        fallbackPricingSection(theme: theme)
                    }

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
                .font(.system(size: 48))
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

            Text("Lleva tu lectura y estudio académico al siguiente nivel.",
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
                desc: "Importa tantos archivos EPUB, PDF, TXT y Markdown como necesites.",
                theme: theme
            )

            benefitRow(
                icon: "pencil.and.outline",
                title: "Destacados y Notas Ilimitadas",
                desc: "Subraya sin restricciones utilizando tus categorías de estudio personalizadas.",
                theme: theme
            )

            benefitRow(
                icon: "sparkles",
                title: "Funciones de IA Avanzadas",
                desc: "Resume capítulos completos, traduce párrafos y obtén explicaciones inteligentes sin cuota gratuita.",
                theme: theme
            )

            benefitRow(
                icon: "cloud.sun.fill",
                title: "Sincronización en la Nube",
                desc: "Respalda tus anotaciones y posición de lectura en todos tus dispositivos.",
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

    // MARK: - Pricing Section

    private func pricingSection(theme: AppTheme) -> some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(products) { product in
                let isSelected = selectedProduct?.id == product.id
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

                                if isYearly {
                                    Text("Ahorra 33%")
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
            Text("No se pudieron cargar los productos de la tienda. Usando precios de referencia:",
                 comment: "Paywall: store error info")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.error(for: theme))
                .multilineTextAlignment(.center)

            // Simulación visual
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text("Premium Mensual")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                    Spacer()
                    Text("$4.99 / mes")
                        .font(AppTypography.body)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                }
                Divider()
                HStack {
                    HStack {
                        Text("Premium Anual")
                        Text("Ahorra 33%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(Capsule())
                    }
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textPrimary(for: theme))
                    Spacer()
                    Text("$39.99 / año")
                        .font(AppTypography.body)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColor.textPrimary(for: theme))
                }
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

            Button(String(localized: "Simular suscripción Premium", comment: "Paywall: simulate action")) {
                simulatePremiumPurchase()
            }
            .font(AppTypography.body)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppColor.accent(for: theme))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
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
                    .font(AppTypography.body)
                    .fontWeight(.bold)
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
            .font(AppTypography.caption)
            .foregroundStyle(AppColor.accent(for: theme))

            Text("Suscripción auto-renovable. El cobro se realizará a tu cuenta de Apple al confirmar la compra. Se renovará automáticamente salvo que la canceles al menos 24 horas antes del fin del período activo.",
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
            // Simular usando el MockSubscriptionService
            if let mock = dependencies.subscriptionService as? MockSubscriptionService {
                mock.hasActiveSubscription = true
                mock.activeEntitlement = SubscriptionEntitlement(
                    productID: "com.lectoria.premium.monthly",
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
