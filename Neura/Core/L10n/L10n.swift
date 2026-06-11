import L10n_swift

// swiftlint:disable type_body_length file_length
enum L10n {

    // MARK: - Common
    enum Common {
        static var neura: String { "common.neura".l10n() }
        static var cancel: String { "common.cancel".l10n() }
        static var done: String { "common.done".l10n() }
        static var save: String { "common.save".l10n() }
        static var close: String { "common.close".l10n() }
        static var delete: String { "common.delete".l10n() }
        static var share: String { "common.share".l10n() }
        static var add: String { "common.add".l10n() }
        static var edit: String { "common.edit".l10n() }
        static var rename: String { "common.rename".l10n() }
        static var info: String { "common.info".l10n() }
        static var retry: String { "common.retry".l10n() }
        static var back: String { "common.back".l10n() }
        static var notes: String { "common.notes".l10n() }
        static var optional: String { "common.optional".l10n() }
        static var notNow: String { "common.notNow".l10n() }
        static var maybeLater: String { "common.maybeLater".l10n() }
        static var skipForNow: String { "common.skipForNow".l10n() }
        static var thisActionCannotBeUndone: String { "common.thisActionCannotBeUndone".l10n() }
        static var areYouSure: String { "common.areYouSure".l10n() }
        static var select: String { "common.select".l10n() }
        static var deselect: String { "common.deselect".l10n() }
        static var saving: String { "common.saving".l10n() }
        static var loading: String { "common.loading".l10n() }
        static var skip: String { "common.skip".l10n() }
        static var create: String { "common.create".l10n() }
        static var error: String { "common.error".l10n() }
        static var ok: String { "common.ok".l10n() }
    }

    // MARK: - Onboarding
    enum Onboarding {
        enum Welcome {
            static var title: String { "onboarding.welcome.title".l10n() }
            static var subtitle: String { "onboarding.welcome.subtitle".l10n() }
            static var continueApple: String { "onboarding.welcome.continueApple".l10n() }
            static var continueGoogle: String { "onboarding.welcome.continueGoogle".l10n() }
            static var encrypted: String { "onboarding.welcome.encrypted".l10n() }
        }

        enum StoreAndShare {
            static var title: String    { "onboarding.storeAndShare.title".l10n() }
            static var subtitle: String { "onboarding.storeAndShare.subtitle".l10n() }
            static var q1: String       { "onboarding.storeAndShare.q1".l10n() }
            static var q2: String       { "onboarding.storeAndShare.q2".l10n() }
            static var q3: String       { "onboarding.storeAndShare.q3".l10n() }
            static var q4: String       { "onboarding.storeAndShare.q4".l10n() }
            static var q5: String       { "onboarding.storeAndShare.q5".l10n() }
        }

        enum QRShare {
            static var title: String            { "onboarding.qrShare.title".l10n() }
            static var subtitle: String         { "onboarding.qrShare.subtitle".l10n() }
            static var mediaAccessibility: String { "onboarding.qrShare.mediaAccessibility".l10n() }
        }

        enum Statistics {
            static var number: String { "onboarding.statistics.number".l10n() }
            static var body: String   { "onboarding.statistics.body".l10n() }
        }

        enum RecordsLocation {
            static var title: String      { "onboarding.recordsLocation.title".l10n() }
            static var email: String      { "onboarding.recordsLocation.email".l10n() }
            static var whatsapp: String   { "onboarding.recordsLocation.whatsapp".l10n() }
            static var folder: String     { "onboarding.recordsLocation.folder".l10n() }
            static var shelf: String      { "onboarding.recordsLocation.shelf".l10n() }
            static var everywhere: String { "onboarding.recordsLocation.everywhere".l10n() }
        }

        enum DocumentScan {
            static var title: String { "onboarding.documentScan.title".l10n() }
            static var subtitle: String { "onboarding.documentScan.subtitle".l10n() }
        }

        enum Privacy {
            static var title: String { "onboarding.privacy.title".l10n() }
            static var subtitle: String { "onboarding.privacy.subtitle".l10n() }
        }

        enum MedicalAreas {
            static var title: String { "onboarding.medicalAreas.title".l10n() }
            static var subtitle: String { "onboarding.medicalAreas.subtitle".l10n() }
        }

        enum Profile {
            static var title: String { "onboarding.profile.title".l10n() }
            static var subtitle: String { "onboarding.profile.subtitle".l10n() }
            static var fullName: String { "onboarding.profile.fullName".l10n() }
            static var fullNamePlaceholder: String { "onboarding.profile.fullNamePlaceholder".l10n() }
            static var dateOfBirth: String { "onboarding.profile.dateOfBirth".l10n() }
            static var day: String { "onboarding.profile.day".l10n() }
            static var month: String { "onboarding.profile.month".l10n() }
            static var year: String { "onboarding.profile.year".l10n() }
        }

        enum Location {
            static var title: String { "onboarding.location.title".l10n() }
            static var subtitle: String { "onboarding.location.subtitle".l10n() }
            static var city: String { "onboarding.location.city".l10n() }
            static var cityPlaceholder: String { "onboarding.location.cityPlaceholder".l10n() }
            static var country: String { "onboarding.location.country".l10n() }
            static var countryPlaceholder: String { "onboarding.location.countryPlaceholder".l10n() }
        }

        enum ProfileCardIntro {
            static var title: String    { "onboarding.profileCardIntro.title".l10n() }
            static var subtitle: String { "onboarding.profileCardIntro.subtitle".l10n() }
        }

        enum ProfileCard {
            static var title: String    { "onboarding.profileCard.title".l10n() }
            static var subtitle: String { "onboarding.profileCard.subtitle".l10n() }
            static var useThisCard: String { "onboarding.profileCard.useThisCard".l10n() }
            static var yourCity: String { "onboarding.profileCard.yourCity".l10n() }
        }

        enum Emergency {
            static var title: String { "onboarding.emergency.title".l10n() }
            static var subtitle: String { "onboarding.emergency.subtitle".l10n() }
            static var contactName: String { "onboarding.emergency.contactName".l10n() }
            static var contactNamePlaceholder: String { "onboarding.emergency.contactNamePlaceholder".l10n() }
            static var phone: String { "onboarding.emergency.phone".l10n() }
            static var phonePlaceholder: String { "onboarding.emergency.phonePlaceholder".l10n() }
            static var bloodType: String { "onboarding.emergency.bloodType".l10n() }
            static var yourNamePlaceholder: String { "onboarding.emergency.yourNamePlaceholder".l10n() }
            static var contactPlaceholder: String { "onboarding.emergency.contactPlaceholder".l10n() }
            static var bloodTypePlaceholder: String { "onboarding.emergency.bloodTypePlaceholder".l10n() }
        }

        enum Biometrics {
            static var title: String { "onboarding.biometrics.title".l10n() }
            static func subtitle(_ biometricLabel: String) -> String {
                "onboarding.biometrics.subtitleFormat".l10n(args: [biometricLabel])
            }
            static func enable(_ biometricLabel: String) -> String {
                "onboarding.biometrics.enableFormat".l10n(args: [biometricLabel])
            }
        }

        enum EmergencyCard {
            static var title: String { "onboarding.emergencyCard.title".l10n() }
            static var subtitle: String { "onboarding.emergencyCard.subtitle".l10n() }
            static var nameLabel: String { "onboarding.emergencyCard.nameLabel".l10n() }
            static var emergencyContactLabel: String { "onboarding.emergencyCard.emergencyContactLabel".l10n() }
            static var bloodTypeLabel: String { "onboarding.emergencyCard.bloodTypeLabel".l10n() }
            static var notSet: String { "onboarding.emergencyCard.notSet".l10n() }
            static var poweredBy: String { "onboarding.emergencyCard.poweredBy".l10n() }
        }

        enum HealthKit {
            static var title: String { "onboarding.healthKit.title".l10n() }
            static var subtitle: String { "onboarding.healthKit.subtitle".l10n() }
            static var importHeight: String { "onboarding.healthKit.importHeight".l10n() }
            static var importHeightSub: String { "onboarding.healthKit.importHeightSub".l10n() }
            static var importWeight: String { "onboarding.healthKit.importWeight".l10n() }
            static var importWeightSub: String { "onboarding.healthKit.importWeightSub".l10n() }
            static var importSex: String { "onboarding.healthKit.importSex".l10n() }
            static var importSexSub: String { "onboarding.healthKit.importSexSub".l10n() }
            static var privacyNote: String { "onboarding.healthKit.privacyNote".l10n() }
            static var connect: String { "onboarding.healthKit.connect".l10n() }
        }

        enum Notifications {
            static var title: String { "onboarding.notifications.title".l10n() }
            static var subtitle: String { "onboarding.notifications.subtitle".l10n() }
            static var allow: String { "onboarding.notifications.allow".l10n() }
        }

        enum HealthData {
            static var title: String { "onboarding.healthData.title".l10n() }
            static var subtitle: String { "onboarding.healthData.subtitle".l10n() }
            static var height: String { "onboarding.healthData.height".l10n() }
            static var weight: String { "onboarding.healthData.weight".l10n() }
            static var biologicalSex: String { "onboarding.healthData.biologicalSex".l10n() }
            static var useThisData: String { "onboarding.healthData.useThisData".l10n() }
            static var enterManually: String { "onboarding.healthData.enterManually".l10n() }
        }

        enum Medical {
            static var title: String { "onboarding.medical.title".l10n() }
            static var subtitle: String { "onboarding.medical.subtitle".l10n() }
            static var medications: String { "onboarding.medical.medications".l10n() }
            static var medicationsPlaceholder: String { "onboarding.medical.medicationsPlaceholder".l10n() }
            static var allergies: String { "onboarding.medical.allergies".l10n() }
            static var allergiesPlaceholder: String { "onboarding.medical.allergiesPlaceholder".l10n() }
            static var conditions: String { "onboarding.medical.conditions".l10n() }
            static var conditionsPlaceholder: String { "onboarding.medical.conditionsPlaceholder".l10n() }
        }

        enum Documents {
            static var title: String { "onboarding.documents.title".l10n() }
            static var subtitle: String { "onboarding.documents.subtitle".l10n() }
            static var scanTitle: String { "onboarding.documents.scanTitle".l10n() }
            static var scanSubtitle: String { "onboarding.documents.scanSubtitle".l10n() }
            static var categorizeTitle: String { "onboarding.documents.categorizeTitle".l10n() }
            static var categorizeSubtitle: String { "onboarding.documents.categorizeSubtitle".l10n() }
            static var qrTitle: String { "onboarding.documents.qrTitle".l10n() }
            static var qrSubtitle: String { "onboarding.documents.qrSubtitle".l10n() }
        }

        enum Goals {
            static var title: String { "onboarding.goals.title".l10n() }
            static var subtitle: String { "onboarding.goals.subtitle".l10n() }
        }

        enum Scanning {
            static var scanLabel: String { "onboarding.scanning.scanLabel".l10n() }
            static var scanSubtitleText: String { "onboarding.scanning.scanSubtitleText".l10n() }
            static var organizeLabel: String { "onboarding.scanning.organizeLabel".l10n() }
            static var organizeSubtitle: String { "onboarding.scanning.organizeSubtitle".l10n() }
            static var shareLabel: String { "onboarding.scanning.shareLabel".l10n() }
            static var shareSubtitleText: String { "onboarding.scanning.shareSubtitleText".l10n() }
            static var scanning: String { "onboarding.scanning.scanning".l10n() }
            static var bloodTest: String { "onboarding.scanning.bloodTest".l10n() }
            static var readyToShare: String { "onboarding.scanning.readyToShare".l10n() }
        }

        enum Calculating {
            static var building: String { "onboarding.calculating.building".l10n() }
            static var personalizing: String { "onboarding.calculating.personalizing".l10n() }
            static var allSet: String { "onboarding.calculating.allSet".l10n() }
            static func allSetName(_ name: String) -> String {
                "onboarding.calculating.allSetNameFormat".l10n(args: [name])
            }
            static var welcome: String { "onboarding.calculating.welcome".l10n() }
            static func profileCreated(_ name: String) -> String {
                "onboarding.calculating.profileCreatedFormat".l10n(args: [name])
            }
            static var medicalAreaSingle: String { "onboarding.calculating.medicalAreaSingle".l10n() }
            static func medicalAreas(_ count: Int) -> String {
                "onboarding.calculating.medicalAreaFormat".l10n(args: [count])
            }
            static var emergencyContact: String { "onboarding.calculating.emergencyContact".l10n() }
            static var healthConnected: String { "onboarding.calculating.healthConnected".l10n() }
            static var healthEntrySingle: String { "onboarding.calculating.healthEntrySingle".l10n() }
            static func healthEntries(_ count: Int) -> String {
                "onboarding.calculating.healthEntryFormat".l10n(args: [count])
            }
            static var healthCardReady: String { "onboarding.calculating.healthCardReady".l10n() }
            static func progress(_ current: Int, _ total: Int) -> String {
                "onboarding.calculating.progressFormat".l10n(args: [current, total])
            }
        }
    }

    // MARK: - Home
    enum Home {
        enum Greeting {
            static var morning: String { "home.greeting.morning".l10n() }
            static var afternoon: String { "home.greeting.afternoon".l10n() }
            static var evening: String { "home.greeting.evening".l10n() }
        }
        static var recent: String { "home.recent".l10n() }
        static var empty: String { "home.empty".l10n() }
        static var customizeCard: String { "home.customizeCard".l10n() }
        static var shareHealthProfile: String { "home.shareHealthProfile".l10n() }
        static var completeProfile: String { "home.completeProfile".l10n() }

        enum UploadLimit {
            static func remaining(_ text: String) -> String {
                "home.uploadLimit.remainingFormat".l10n(args: [text])
            }
            static var upgrade: String { "home.uploadLimit.upgrade".l10n() }
            static var reachedTitle: String { "home.uploadLimit.reachedTitle".l10n() }
            static var reachedSubtitle: String { "home.uploadLimit.reachedSubtitle".l10n() }
        }

        enum CardBackground {
            static var title: String { "home.cardBackground.title".l10n() }
            static var upload: String { "home.cardBackground.upload".l10n() }
            static var yourPhotos: String { "home.cardBackground.yourPhotos".l10n() }
            static var presets: String { "home.cardBackground.presets".l10n() }
            static var gradients: String { "home.cardBackground.gradients".l10n() }
        }

        enum ShareHealth {
            static var title: String { "home.shareHealth.title".l10n() }
            static var subtitle: String { "home.shareHealth.subtitle".l10n() }
            static var share: String { "home.shareHealth.share".l10n() }
        }

        enum AppUpdate {
            static var title: String { "home.appUpdate.title".l10n() }
            static func subtitle(_ version: String) -> String {
                "home.appUpdate.subtitleFormat".l10n(args: [version])
            }
            static var updateNow: String { "home.appUpdate.updateNow".l10n() }
        }
    }

    // MARK: - Emergency
    enum Emergency {
        static var title: String { "emergency.title".l10n() }
        static var subtitle: String { "emergency.subtitle".l10n() }
        static var inCaseOf: String { "emergency.inCaseOf".l10n() }
        static var emergency: String { "emergency.emergency".l10n() }
        static var poweredBy: String { "emergency.poweredBy".l10n() }
        static var callContact: String { "emergency.callContact".l10n() }
        static var share: String { "emergency.share".l10n() }
    }

    // MARK: - Coachmark
    enum Coachmark {
        static var title: String { "coachmark.documentUpload.title".l10n() }
        static var subtitle: String { "coachmark.documentUpload.subtitle".l10n() }
    }

    // MARK: - Documents
    enum Documents {
        static var title: String { "documents.title".l10n() }
        static var deselectAll: String { "documents.deselectAll".l10n() }
        static var selectAll: String { "documents.selectAll".l10n() }
        static var done: String { "documents.done".l10n() }
        static var select: String { "documents.select".l10n() }
        static var searchPlaceholder: String { "documents.searchPlaceholder".l10n() }
        static func count(_ n: Int) -> String { "documents.countFormat".l10n(args: [n]) }
        static var noMatchingTitle: String { "documents.noMatchingTitle".l10n() }
        static var noDocumentsTitle: String { "documents.noDocumentsTitle".l10n() }
        static var noMatchingMessage: String { "documents.noMatchingMessage".l10n() }
        static var noDocumentsMessage: String { "documents.noDocumentsMessage".l10n() }
        static var addDocument: String { "documents.addDocument".l10n() }
        static var scan: String { "documents.scan".l10n() }
        static var uploadPhotos: String { "documents.uploadPhotos".l10n() }
        static var importFile: String { "documents.importFile".l10n() }
        static func deleteAlertTitle(_ count: Int) -> String {
            "documents.deleteAlertTitleFormat".l10n(args: [count])
        }
        static func selectedCount(_ count: Int) -> String {
            "documents.selectedCountFormat".l10n(args: [count])
        }
        static var noneSelected: String { "documents.noneSelected".l10n() }
        static func selected(_ count: Int) -> String {
            "documents.selectedFormat".l10n(args: [count])
        }
        static var newFolderMessage: String { "documents.newFolderMessage".l10n() }

        enum PhotoAccess {
            static var title: String { "documents.photoAccess.title".l10n() }
            static var openSettings: String { "documents.photoAccess.openSettings".l10n() }
            static var message: String { "documents.photoAccess.message".l10n() }
        }

        enum Filter {
            static var title: String { "documents.filter.title".l10n() }
            static var button: String { "documents.filter.button".l10n() }
            static var order: String { "documents.filter.order".l10n() }
            static var category: String { "documents.filter.category".l10n() }
            static var specialization: String { "documents.filter.specialization".l10n() }
            static var clearAll: String { "documents.filter.clearAll".l10n() }
            static func result(_ count: Int) -> String { "documents.filter.resultFormat".l10n(args: [count]) }
            static var newest: String { "documents.filter.newest".l10n() }
            static var oldest: String { "documents.filter.oldest".l10n() }
            static var nameAZ: String { "documents.filter.nameAZ".l10n() }
        }

        enum Viewer {
            static var rename: String { "documents.viewer.rename".l10n() }
            static var info: String { "documents.viewer.info".l10n() }
            static var share: String { "documents.viewer.share".l10n() }
            static var shareQR: String { "documents.viewer.shareQR".l10n() }
            static var delete: String { "documents.viewer.delete".l10n() }
            static var infoTitle: String { "documents.viewer.infoTitle".l10n() }
            static var fileNotFound: String { "documents.viewer.fileNotFound".l10n() }
            static var fileNotFoundMessage: String { "documents.viewer.fileNotFoundMessage".l10n() }
            static var loading: String { "documents.viewer.loading".l10n() }
            static var deleteTitle: String { "documents.viewer.deleteTitle".l10n() }
            static var deleteMessage: String { "documents.viewer.deleteMessage".l10n() }
            static var renameTitle: String { "documents.viewer.renameTitle".l10n() }
            static var renamePlaceholder: String { "documents.viewer.renamePlaceholder".l10n() }
            static var renameMessage: String { "documents.viewer.renameMessage".l10n() }
            static func pagesCount(_ n: Int) -> String { "documents.viewer.pagesCountFormat".l10n(args: [n]) }
            static var name: String { "documents.viewer.name".l10n() }
            static var date: String { "documents.viewer.date".l10n() }
            static var pages: String { "documents.viewer.pages".l10n() }
            static var type: String { "documents.viewer.type".l10n() }
            static var category: String { "documents.viewer.category".l10n() }
            static var doctor: String { "documents.viewer.doctor".l10n() }
            static var notes: String { "documents.viewer.notes".l10n() }
            static var tags: String { "documents.viewer.tags".l10n() }
        }

        enum Section {
            static var today: String { "documents.section.today".l10n() }
            static var yesterday: String { "documents.section.yesterday".l10n() }
            static var thisWeek: String { "documents.section.thisWeek".l10n() }
            static var thisMonth: String { "documents.section.thisMonth".l10n() }
        }

        enum Category {
            // Folder / category display names
            static var bloodTests: String { "documents.category.name.bloodTests".l10n() }
            static var medicalLetter: String { "documents.category.name.medicalLetter".l10n() }
            static var consultations: String { "documents.category.name.consultations".l10n() }
            static var prescriptions: String { "documents.category.name.prescriptions".l10n() }
            static var hospitalization: String { "documents.category.name.hospitalization".l10n() }
            static var vaccination: String { "documents.category.name.vaccination".l10n() }
            static var imaging: String { "documents.category.name.imaging".l10n() }

            static var noDocumentsYet: String { "documents.category.noDocumentsYet".l10n() }
            static func searchFormat(_ category: String) -> String { "documents.category.searchFormat".l10n(args: [category]) }
            static func emptyDescriptionFormat(_ category: String) -> String { "documents.category.emptyDescriptionFormat".l10n(args: [category]) }
            static var scanFirst: String { "documents.category.scanFirst".l10n() }
            static var addNewFile: String { "documents.category.addNewFile".l10n() }
            static var newFolder: String { "documents.category.newFolder".l10n() }
        }

        enum Folder {
            static var renameTitle: String { "documents.folder.renameTitle".l10n() }
            static var namePlaceholder: String { "documents.folder.namePlaceholder".l10n() }
            static var noDocuments: String { "documents.folder.noDocuments".l10n() }
            static func emptyDescriptionFormat(_ folder: String) -> String { "documents.folder.emptyDescriptionFormat".l10n(args: [folder]) }
        }

        enum AddDocument {
            static var scanSubtitle: String { "documents.addDocument.scanSubtitle".l10n() }
            static var photoSubtitle: String { "documents.addDocument.photoSubtitle".l10n() }
            static var fileSubtitle: String { "documents.addDocument.fileSubtitle".l10n() }
        }

        enum CategoryPicker {
            static var title: String { "documents.categoryPicker.title".l10n() }
            static var subtitle: String { "documents.categoryPicker.subtitle".l10n() }
            static func documentCount(_ n: Int) -> String { "documents.categoryPicker.documentCountFormat".l10n(args: [n]) }
        }

        enum Naming {
            static var title: String { "documents.naming.title".l10n() }
            static func scannedPages(_ count: Int) -> String {
                "documents.naming.scannedPagesFormat".l10n(args: [count])
            }
            static func page(_ number: Int) -> String {
                "documents.naming.pageFormat".l10n(args: [number])
            }
            static var fileName: String { "documents.naming.fileName".l10n() }
            static var fileNamePlaceholder: String { "documents.naming.fileNamePlaceholder".l10n() }
            static func savingTo(_ category: String) -> String {
                "documents.naming.savingToFormat".l10n(args: [category])
            }
            static var saveFile: String { "documents.naming.saveFile".l10n() }
        }

        enum Metadata {
            static var title: String { "documents.metadata.title".l10n() }
            static var category: String { "documents.metadata.category".l10n() }
            static var specialization: String { "documents.metadata.specialization".l10n() }
            static var date: String { "documents.metadata.date".l10n() }
            static var name: String { "documents.metadata.name".l10n() }
            static var doctor: String { "documents.metadata.doctor".l10n() }
            static var notes: String { "documents.metadata.notes".l10n() }
            static var notesPlaceholder: String { "documents.metadata.notesPlaceholder".l10n() }
            static var save: String { "documents.metadata.save".l10n() }
            static var specializationTitle: String { "documents.metadata.specializationTitle".l10n() }
        }
    }

    // MARK: - QR Sharing
    enum QR {
        static var uploading: String { "qr.uploading".l10n() }
        static var scanCode: String { "qr.scanCode".l10n() }
        static var copyLink: String { "qr.copyLink".l10n() }
        static var expired: String { "qr.expired".l10n() }
        static var expiredMessage: String { "qr.expiredMessage".l10n() }
        static var generateNew: String { "qr.generateNew".l10n() }
        static var failed: String { "qr.failed".l10n() }
        static var retry: String { "qr.retry".l10n() }
    }

    // MARK: - Health Profile
    enum HealthProfile {
        static var title: String { "healthProfile.title".l10n() }
        static var generalData: String { "healthProfile.generalData".l10n() }
        static var addField: String { "healthProfile.addField".l10n() }
        static var addSection: String { "healthProfile.addSection".l10n() }
        static var sectionTitlePlaceholder: String { "healthProfile.sectionTitlePlaceholder".l10n() }
        static var fullName: String { "healthProfile.fullName".l10n() }
        static var dateOfBirth: String { "healthProfile.dateOfBirth".l10n() }
        static var gender: String { "healthProfile.gender".l10n() }
        static var height: String { "healthProfile.height".l10n() }
        static var weight: String { "healthProfile.weight".l10n() }
        static var insuranceStatus: String { "healthProfile.insuranceStatus".l10n() }
        static var bloodType: String { "healthProfile.bloodType".l10n() }
        static var emergencyContact: String { "healthProfile.emergencyContact".l10n() }
        static var addName: String { "healthProfile.addName".l10n() }
        static var addDate: String { "healthProfile.addDate".l10n() }
        static var addGender: String { "healthProfile.addGender".l10n() }
        static var addHeight: String { "healthProfile.addHeight".l10n() }
        static var addWeight: String { "healthProfile.addWeight".l10n() }
        static var selectBloodType: String { "healthProfile.selectBloodType".l10n() }
        static var addStatus: String { "healthProfile.addStatus".l10n() }
        static var addContact: String { "healthProfile.addContact".l10n() }
        static var addHealthInfo: String { "healthProfile.addHealthInfo".l10n() }
        static var notesOptional: String { "healthProfile.notesOptional".l10n() }
        static var additionalDetails: String { "healthProfile.additionalDetails".l10n() }
        static var noEntries: String { "healthProfile.noEntries".l10n() }
        static var noEntriesSubtitle: String { "healthProfile.noEntriesSubtitle".l10n() }
        static func editFormat(_ name: String) -> String { "healthProfile.editFormat".l10n(args: [name]) }
        static func deleteFormat(_ name: String) -> String { "healthProfile.deleteFormat".l10n(args: [name]) }
        static func updatedFormat(_ dateString: String) -> String {
            "healthProfile.updatedFormat".l10n(args: [dateString])
        }
        static var valueLabel: String { "healthProfile.valueLabel".l10n() }

        // Field labels not already covered above
        static var fieldName: String { "healthProfile.field.name".l10n() }
        static var myNumber: String { "healthProfile.field.myNumber".l10n() }
        static var emergencyNumber: String { "healthProfile.field.emergencyNumber".l10n() }

        // Add / rename custom field & section
        static var renameFieldTitle: String { "healthProfile.renameFieldTitle".l10n() }
        static var removeFieldMessage: String { "healthProfile.removeFieldMessage".l10n() }
        static var fieldNamePlaceholder: String { "healthProfile.fieldNamePlaceholder".l10n() }
        static var addFieldMessage: String { "healthProfile.addFieldMessage".l10n() }
        static var notes: String { "healthProfile.notes".l10n() }
        static func fieldsFilled(_ filled: Int, _ total: Int) -> String {
            "healthProfile.fieldsFilledFormat".l10n(args: [filled, total])
        }
        static func deleteSection(_ name: String) -> String {
            "healthProfile.deleteSectionFormat".l10n(args: [name])
        }

        // Built-in section titles (stored value stays English; localized only at render)
        enum Section {
            static var knownConditions: String { "healthProfile.section.knownConditions".l10n() }
            static var medications: String { "healthProfile.section.medications".l10n() }
            static var allergies: String { "healthProfile.section.allergies".l10n() }
            static var symptoms: String { "healthProfile.section.symptoms".l10n() }
            static var familyHistory: String { "healthProfile.section.familyHistory".l10n() }
        }

        // Picker option values (stored value stays English; localized only at render)
        enum Option {
            static var male: String { "healthProfile.option.male".l10n() }
            static var female: String { "healthProfile.option.female".l10n() }
            static var preferNotToSay: String { "healthProfile.option.preferNotToSay".l10n() }
            static var insured: String { "healthProfile.option.insured".l10n() }
            static var uninsured: String { "healthProfile.option.uninsured".l10n() }
            static var partiallyInsured: String { "healthProfile.option.partiallyInsured".l10n() }
        }

        // Per-section entry form labels & placeholders
        enum Entry {
            static var addAllergy: String { "healthProfile.entry.allergy.add".l10n() }
            static var deleteAllergy: String { "healthProfile.entry.allergy.delete".l10n() }
            static var allergyName: String { "healthProfile.entry.allergy.name".l10n() }
            static var allergyNamePlaceholder: String { "healthProfile.entry.allergy.namePlaceholder".l10n() }
            static var allergySymptoms: String { "healthProfile.entry.allergy.field1".l10n() }
            static var allergySymptomsPlaceholder: String { "healthProfile.entry.allergy.field1Placeholder".l10n() }
            static var allergyTreatment: String { "healthProfile.entry.allergy.field2".l10n() }
            static var allergyTreatmentPlaceholder: String { "healthProfile.entry.allergy.field2Placeholder".l10n() }

            static var addMedication: String { "healthProfile.entry.medication.add".l10n() }
            static var deleteMedication: String { "healthProfile.entry.medication.delete".l10n() }
            static var medicationName: String { "healthProfile.entry.medication.name".l10n() }
            static var medicationNamePlaceholder: String { "healthProfile.entry.medication.namePlaceholder".l10n() }
            static var medicationDosage: String { "healthProfile.entry.medication.field1".l10n() }
            static var medicationDosagePlaceholder: String { "healthProfile.entry.medication.field1Placeholder".l10n() }
            static var medicationFrequency: String { "healthProfile.entry.medication.field2".l10n() }
            static var medicationFrequencyPlaceholder: String { "healthProfile.entry.medication.field2Placeholder".l10n() }

            static var addCondition: String { "healthProfile.entry.condition.add".l10n() }
            static var deleteCondition: String { "healthProfile.entry.condition.delete".l10n() }
            static var conditionName: String { "healthProfile.entry.condition.name".l10n() }
            static var conditionNamePlaceholder: String { "healthProfile.entry.condition.namePlaceholder".l10n() }
            static var conditionDiagnosed: String { "healthProfile.entry.condition.field1".l10n() }
            static var conditionDiagnosedPlaceholder: String { "healthProfile.entry.condition.field1Placeholder".l10n() }
            static var conditionTreatment: String { "healthProfile.entry.condition.field2".l10n() }
            static var conditionTreatmentPlaceholder: String { "healthProfile.entry.condition.field2Placeholder".l10n() }

            static var addSymptom: String { "healthProfile.entry.symptom.add".l10n() }
            static var deleteSymptom: String { "healthProfile.entry.symptom.delete".l10n() }
            static var symptomName: String { "healthProfile.entry.symptom.name".l10n() }
            static var symptomNamePlaceholder: String { "healthProfile.entry.symptom.namePlaceholder".l10n() }
            static var symptomSeverity: String { "healthProfile.entry.symptom.field1".l10n() }
            static var symptomSeverityPlaceholder: String { "healthProfile.entry.symptom.field1Placeholder".l10n() }
            static var symptomDuration: String { "healthProfile.entry.symptom.field2".l10n() }
            static var symptomDurationPlaceholder: String { "healthProfile.entry.symptom.field2Placeholder".l10n() }

            static var addFamily: String { "healthProfile.entry.family.add".l10n() }
            static var deleteFamily: String { "healthProfile.entry.family.delete".l10n() }
            static var familyCondition: String { "healthProfile.entry.family.name".l10n() }
            static var familyConditionPlaceholder: String { "healthProfile.entry.family.namePlaceholder".l10n() }
            static var familyRelation: String { "healthProfile.entry.family.field1".l10n() }
            static var familyRelationPlaceholder: String { "healthProfile.entry.family.field1Placeholder".l10n() }
            static var familyDetails: String { "healthProfile.entry.family.field2".l10n() }
            static var familyDetailsPlaceholder: String { "healthProfile.entry.family.field2Placeholder".l10n() }

            static var addEntry: String { "healthProfile.entry.default.add".l10n() }
            static var deleteEntry: String { "healthProfile.entry.default.delete".l10n() }
            static var defaultName: String { "healthProfile.entry.default.name".l10n() }
            static var defaultNamePlaceholder: String { "healthProfile.entry.default.namePlaceholder".l10n() }
            static var defaultDetails: String { "healthProfile.entry.default.field1".l10n() }
            static var defaultDetailsPlaceholder: String { "healthProfile.entry.default.field1Placeholder".l10n() }
            static var defaultInfo: String { "healthProfile.entry.default.field2".l10n() }
            static var defaultInfoPlaceholder: String { "healthProfile.entry.default.field2Placeholder".l10n() }
        }

        enum Report {
            static var title: String { "healthProfile.report.title".l10n() }
            static var subtitle: String { "healthProfile.report.subtitle".l10n() }
            static var whatsIncluded: String { "healthProfile.report.whatsIncluded".l10n() }
            static var generating: String { "healthProfile.report.generating".l10n() }
            static var generate: String { "healthProfile.report.generate".l10n() }
            static var feature1Title: String { "healthProfile.report.feature1Title".l10n() }
            static var feature1Subtitle: String { "healthProfile.report.feature1Subtitle".l10n() }
            static var feature2Title: String { "healthProfile.report.feature2Title".l10n() }
            static var feature2Subtitle: String { "healthProfile.report.feature2Subtitle".l10n() }
            static var feature3Title: String { "healthProfile.report.feature3Title".l10n() }
            static var feature3Subtitle: String { "healthProfile.report.feature3Subtitle".l10n() }
            static var feature4Title: String { "healthProfile.report.feature4Title".l10n() }
            static var feature4Subtitle: String { "healthProfile.report.feature4Subtitle".l10n() }
        }
    }

    // MARK: - Profile
    enum Profile {
        static var title: String { "profile.title".l10n() }

        enum Section {
            static var profile: String { "profile.section.profile".l10n() }
            static var preferences: String { "profile.section.preferences".l10n() }
            static var support: String { "profile.section.support".l10n() }
            static var account: String { "profile.section.account".l10n() }
        }

        static var healthProfile: String { "profile.healthProfile".l10n() }
        static var subscription: String { "profile.subscription".l10n() }
        static var security: String { "profile.security".l10n() }
        static var language: String { "profile.language".l10n() }
        static var feedback: String { "profile.feedback".l10n() }

        enum Feedback {
            static var title: String { "profile.feedback.title".l10n() }
            static var emailLabel: String { "profile.feedback.emailLabel".l10n() }
            static var emailPlaceholder: String { "profile.feedback.emailPlaceholder".l10n() }
            static var messageLabel: String { "profile.feedback.messageLabel".l10n() }
            static var messagePlaceholder: String { "profile.feedback.messagePlaceholder".l10n() }
            static var submit: String { "profile.feedback.submit".l10n() }
            static var errorMessage: String { "profile.feedback.errorMessage".l10n() }
        }

        static var contactUs: String { "profile.contactUs".l10n() }
        static var logOut: String { "profile.logOut".l10n() }
        static var deleteAccount: String { "profile.deleteAccount".l10n() }
        static var logOutMessage: String { "profile.logOutMessage".l10n() }
        static var deleteAccountMessage: String { "profile.deleteAccountMessage".l10n() }
        static var deletingAccount: String { "profile.deletingAccount".l10n() }
        static var deleteAccountErrorTitle: String { "profile.deleteAccountErrorTitle".l10n() }
        static var deleteAccountErrorMessage: String { "profile.deleteAccountErrorMessage".l10n() }
        static func biometricLock(_ biometricLabel: String) -> String {
            "profile.biometricLockFormat".l10n(args: [biometricLabel])
        }
        static var biometricUnavailableSubtitle: String { "profile.biometricUnavailableSubtitle".l10n() }
        static var biometricUnavailableTitle: String { "profile.biometricUnavailableTitle".l10n() }
        static var biometricUnavailableMessage: String { "profile.biometricUnavailableMessage".l10n() }

        enum Pro {
            static var title: String { "profile.pro.title".l10n() }
            static var unlimitedAccess: String { "profile.pro.unlimitedAccess".l10n() }
            static var getTitle: String { "profile.pro.getTitle".l10n() }
            static var getSubtitle: String { "profile.pro.getSubtitle".l10n() }
            static var upgrade: String { "profile.pro.upgrade".l10n() }
        }

        enum Subscription {
            static var description: String { "profile.subscriptionDetail.description".l10n() }
            static var periodMonthly: String { "profile.subscriptionDetail.periodMonthly".l10n() }
            static var periodYearly: String { "profile.subscriptionDetail.periodYearly".l10n() }
            static var perMonth: String { "profile.subscriptionDetail.perMonth".l10n() }
            static var perYear: String { "profile.subscriptionDetail.perYear".l10n() }
            static func planTitle(_ period: String) -> String {
                "profile.subscriptionDetail.planTitleFormat".l10n(args: [period])
            }
            static func renewsOn(_ date: String) -> String {
                "profile.subscriptionDetail.renewsOnFormat".l10n(args: [date])
            }
            static func expiresOn(_ date: String) -> String {
                "profile.subscriptionDetail.expiresOnFormat".l10n(args: [date])
            }
        }
    }

    // MARK: - Paywall
    enum Paywall {
        static var title: String { "paywall.title".l10n() }
        static var subtitle: String { "paywall.subtitle".l10n() }
        static func continueWith(_ plan: String) -> String {
            "paywall.continueFormat".l10n(args: [plan])
        }
        static var restore: String { "paywall.restore".l10n() }

        static var getPro: String { "paywall.getPro".l10n() }
        static var cancelAnytime: String { "paywall.cancelAnytime".l10n() }
        static var bestValue: String { "paywall.bestValue".l10n() }
        static var planMonthly: String { "paywall.planMonthly".l10n() }
        static var planYearly: String { "paywall.planYearly".l10n() }
        static var perMonthSuffix: String { "paywall.perMonthSuffix".l10n() }
        static var perYearSuffix: String { "paywall.perYearSuffix".l10n() }
        static var periodMonth: String { "paywall.periodMonth".l10n() }
        static var periodYear: String { "paywall.periodYear".l10n() }
        static func perMonthOnly(_ price: String) -> String {
            "paywall.perMonthOnlyFormat".l10n(args: [price])
        }
        static var termsOfUse: String { "paywall.termsOfUse".l10n() }
        static var privacyPolicy: String { "paywall.privacyPolicy".l10n() }
        static func renewalDisclosure(_ price: String, _ period: String) -> String {
            "paywall.renewalDisclosureFormat".l10n(args: [price, period])
        }
        static var purchasePending: String { "paywall.purchasePending".l10n() }
        static var purchaseFailed: String { "paywall.purchaseFailed".l10n() }
        static var restoreNone: String { "paywall.restoreNone".l10n() }

        enum Slide {
            static var title1: String { "paywall.slide1.title".l10n() }
            static var subtitle1: String { "paywall.slide1.subtitle".l10n() }
            static var title2: String { "paywall.slide2.title".l10n() }
            static var subtitle2: String { "paywall.slide2.subtitle".l10n() }
            static var title3: String { "paywall.slide3.title".l10n() }
            static var subtitle3: String { "paywall.slide3.subtitle".l10n() }
            static var title4: String { "paywall.slide4.title".l10n() }
            static var subtitle4: String { "paywall.slide4.subtitle".l10n() }
        }
    }
}
// swiftlint:enable type_body_length file_length
