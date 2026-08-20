import MyQuickFinderKit

@MainActor
enum AppComposition {
    static func makePanelController(
        bindings: KeyBindingStore,
        settings: SettingsPresenter
    ) -> PanelController {
        let browser = BrowserModel()
        let reader = DirectoryReader()
        let model = PanelModel(
            browser: browser,
            picker: PathPickerModel(home: browser.home, reader: reader),
            storage: FavoriteFileStorage(directoryName: AppServices.storageDirectoryName)
        )
        return PanelController(
            model: model,
            terminal: SystemTerminalLauncher(),
            bindings: bindings,
            settings: settings
        )
    }
}
