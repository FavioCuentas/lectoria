import SwiftUI

// MARK: - MyDevicesView

/// Pantalla de administración de dispositivos asociados a la cuenta del usuario.
///
/// Muestra los dispositivos autorizados, la capacidad según el plan (1 en Free / 3 en Premium)
/// y aplica la regla de seguridad de 30 días mínimos para desvincular un equipo.
struct MyDevicesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppDependencies.self) private var dependencies

    @State private var devices: [RegisteredDevice] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showPaywall = false
    @State private var deviceManagementService: DeviceManagementService?

    var body: some View {
        let theme = themeManager.currentTheme

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header de capacidad del plan
                    capacityHeader(theme: theme)

                    // Lista de dispositivos
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        deviceListSection(theme: theme)
                    }

                    // Información sobre la política de 30 días
                    policyInfoCard(theme: theme)
                }
                .padding(.horizontal, AppSpacing.screenHorizontal)
                .padding(.vertical, AppSpacing.md)
            }
            .background(AppColor.background(for: theme))
            .navigationTitle("Mis Dispositivos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") {
                        dismiss()
                    }
                    .font(AppTypography.body)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                let service = DeviceManagementService(entitlementService: dependencies.entitlementService)
                self.deviceManagementService = service
                await loadDevices(service: service)
            }
            .alert("Información de Dispositivo", isPresented: $showErrorAlert) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    // MARK: - Capacity Header

    private func capacityHeader(theme: AppTheme) -> some View {
        let isPremium = dependencies.subscriptionService.hasActiveSubscription
        let maxDevices = isPremium ? 3 : 1

        return HStack(spacing: AppSpacing.md) {
            Image(systemName: "laptopcomputer.and.iphone")
                .font(.system(size: 28))
                .foregroundStyle(AppColor.accent(for: theme))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(devices.count) / \(maxDevices) Dispositivos Activos", comment: "Header capacity title")
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColor.textPrimary(for: theme))

                Text(isPremium ? "Tu plan Premium te permite usar hasta 3 dispositivos en simultáneo." : "El plan Free permite 1 dispositivo. Suscríbete a Premium para conectar hasta 3.", comment: "Header capacity subtitle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary(for: theme))
            }

            Spacer()

            if !isPremium {
                Button("Ampliación") {
                    showPaywall = true
                }
                .font(AppTypography.caption.weight(.bold))
                .foregroundStyle(AppColor.accent(for: theme))
            }
        }
        .padding(AppSpacing.md)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
    }

    // MARK: - Device List

    private func deviceListSection(theme: AppTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Dispositivos Registrados", comment: "Section title")
                .font(AppTypography.caption.weight(.bold))
                .foregroundStyle(AppColor.textSecondary(for: theme))

            ForEach(devices) { dev in
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: dev.platform == "iPadOS" ? "ipad" : "iphone")
                        .font(.system(size: 24))
                        .foregroundStyle(AppColor.accent(for: theme))
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: AppSpacing.xs) {
                            Text(dev.name)
                                .font(AppTypography.bodyBold)
                                .foregroundStyle(AppColor.textPrimary(for: theme))

                            if dev.isCurrentDevice {
                                Text("Este dispositivo", comment: "Current device badge")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, 2)
                                    .background(AppColor.accent(for: theme))
                                    .clipShape(Capsule())
                            }
                        }

                        Text("Registrado el \(dev.addedAt.formatted(date: .abbreviated, time: .omitted))", comment: "Registration date")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary(for: theme))
                    }

                    Spacer()

                    if !dev.isCurrentDevice {
                        if dev.canBeRemoved {
                            Button(role: .destructive) {
                                removeDevice(dev)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.red)
                            }
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AppColor.textTertiary(for: theme))
                                Text("Faltan \(dev.daysUntilRemovalAllowed)d", comment: "Days left for removal")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(AppColor.textTertiary(for: theme))
                            }
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColor.surface(for: theme))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
            }
        }
    }

    // MARK: - Policy Info

    private func policyInfoCard(theme: AppTheme) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "shield.checkmark.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppColor.accent(for: theme))

            Text("Política de seguridad: Para evitar la rotación excesiva, cada dispositivo debe permanecer al menos 30 días registrado antes de ser desvinculado.", comment: "Policy notice")
                .font(.system(size: 11))
                .foregroundStyle(AppColor.textSecondary(for: theme))
        }
        .padding(AppSpacing.md)
        .background(AppColor.surface(for: theme))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    // MARK: - Logic

    private func loadDevices(service: DeviceManagementService) async {
        isLoading = true
        do {
            let loaded = try await service.fetchRegisteredDevices()
            await MainActor.run {
                self.devices = loaded
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func removeDevice(_ dev: RegisteredDevice) {
        guard let service = deviceManagementService else { return }
        Task {
            do {
                try await service.removeDevice(id: dev.id)
                await loadDevices(service: service)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
}
