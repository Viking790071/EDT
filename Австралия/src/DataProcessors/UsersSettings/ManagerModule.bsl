#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions related to getting form settings.

// Gets a form settings list for the specified user.
//
// Parameters:
//   Username - String - name of an infobase user, for whom form settings are received.
//                              
// 
// Returns
//   ValueList - list of forms where the passed user has settings.
//
Function AllFormSettings(Username)
	
	FormsList = MetadataObjectForms();
	
	// Adding standard forms to the list.
	FormsList.Add("ExternalDataProcessor.StandardEventLog.Form.EventsJournal", 
		NStr("ru = 'Стандартные.Журнал регистрации'; en = 'Standard.Event log'; pl = 'Standardowe.Dziennik wydarzeń';es_ES = 'Estándar.Registro de eventos';es_CO = 'Estándar.Registro de eventos';tr = 'Standart. Olay günlüğü';it = 'Standard.Event registro';de = 'Standard.Ereignisprotokoll'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardEventLog.Form.EventForm", 
		NStr("ru = 'Стандартные.Журнал регистрации, Событие'; en = 'Standard.Event log, Event'; pl = 'Standardowe.Dziennik wydarzeń, Wydarzenia';es_ES = 'Estándar.Registro de eventos, Evento';es_CO = 'Estándar.Registro de eventos, Evento';tr = 'Standart. Olay günlüğü, Olay';it = 'Standard.Event registro, Eventi';de = 'Standard.Ereignisprotokoll, Ereignis'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardEventLog.Form.EventsJournalFilter", 
		NStr("ru = 'Стандартные.Журнал регистрации, Настройка отбора событий'; en = 'Standard.Event log, Event filter settings'; pl = 'Standardowe.Dziennik wydarzeń, Dostosuj wybór wydarzenia';es_ES = 'Estándar.Registro de eventos, Personalizar la selección de eventos';es_CO = 'Estándar.Registro de eventos, Personalizar la selección de eventos';tr = 'Standart. Olay günlüğü, Olay seçimini özelleştir';it = 'Standard. Registro, Impostazione selezione eventi';de = 'Standard.Ereignisprotokoll, Anpassen der Ereignisauswahl'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardFindByRef.Form.MainForm", 
		NStr("ru = 'Стандартные.Поиск ссылок на объект'; en = 'Standard.Find references to objects'; pl = 'Standardowe.Wyszukaj linki do obiektu';es_ES = 'Estándar.Buscar los enlaces a objetos';es_CO = 'Estándar.Buscar los enlaces a objetos';tr = 'Standart. Nesne bağlantılarını ara';it = 'Standard.Ricerca link all''oggetto';de = 'Standard.Suchen Sie nach Links zum Objekt'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardFullTextSearchManagement.Form.MainForm", 
		NStr("ru = 'Стандартные.Управление полнотекстовым поиском'; en = 'Standard.Manage Full Text Search'; pl = 'Standardowe.Kierowanie wyszukiwaniem tekstowym';es_ES = 'Estándar.Gestionar la búsqueda de texto completo';es_CO = 'Estándar.Gestionar la búsqueda de texto completo';tr = 'Standart. Tam metin aramayı yönet';it = 'Standard.Gestione della ricerca di testo completo';de = 'Standard.Verwalte Volltextsuche'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardDocumentsPosting.Form.MainForm", 
		NStr("ru = 'Стандартные.Проведение документов'; en = 'Standard.Document Posting'; pl = 'Standardowe.Publikowanie dokumentów';es_ES = 'Estándar.Envío de documentos';es_CO = 'Estándar.Envío de documentos';tr = 'Standart. Belgenin onayı';it = 'Standard.La registrazione dei documenti';de = 'Standard.Dokument Buchung'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardDeleteMarkedObjects.Form.Form", 
		NStr("ru = 'Стандартные.Удаление помеченных объектов'; en = 'Standard.Delete Marked Objects'; pl = 'Standardowe.Usuń wybrane obiekty';es_ES = 'Estándar.Borrar los objetos seleccionados';es_CO = 'Estándar.Borrar los objetos seleccionados';tr = 'Standart. Seçilmiş nesnelerin silinmesi';it = 'Standard.Cancellazione di Oggetti Contrassegnati';de = 'Standard.Löschen ausgewählter Objekte'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardExternalDataSourceManagement.Form.Form", 
		NStr("ru = 'Стандартные.Управление внешними источниками данных'; en = 'Standard.Management of external data sources'; pl = 'Standardowe.Zarządzaj zewnętrznymi źródłami danych';es_ES = 'Estándar.Gestionar las fuentes de datos externos';es_CO = 'Estándar.Gestionar las fuentes de datos externos';tr = 'Standart. Harici veri kaynaklarını yönet';it = 'Standard.Gestione delle fonti dati esterne';de = 'Standard.Verwalte externe Datenquellen'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardTotalsManagement.Form.MainForm", 
		NStr("ru = 'Стандартные.Управление итогами'; en = 'Standard.Totals management'; pl = 'Standardowe.Zarządzanie całkowite';es_ES = 'Estándar.Gestión total';es_CO = 'Estándar.Gestión total';tr = 'Standart. Toplamlar yönetimi';it = 'Standard.Gestione dei risultati';de = 'Standard.Gesamtverwaltung'") , False, PictureLib.Form);
	FormsList.Add("ExternalDataProcessor.StandardActiveUsers.Form.ActiveUsersListForm", 
		NStr("ru = 'Стандартные.Активные пользователи'; en = 'Standard.Active users'; pl = 'Standardowe.Aktywni użytkownicy';es_ES = 'Estándar.Usuarios activos';es_CO = 'Estándar.Usuarios activos';tr = 'Standart. Aktif kullanıcılar';it = 'Standard.Active utenti';de = 'Standard.Aktive Benutzer'") , False, PictureLib.Form);
		
	Return FormSettingsList(FormsList, Username);
	
EndFunction

// Gets the list of configuration forms and populates the following fields:
// Value - form name that serves as a unique ID.
// Presentation - form synonym.
// Picture - a picture that matches the related object.
//
// Parameters:
// List - ValueList - value list to which form details are to be added.
//
// Returns
// ValueList - list of all metadata object forms.
//
Function MetadataObjectForms()
	
	FormsList = New ValueList;
	
	For Each Form In Metadata.CommonForms Do
		FormsList.Add("CommonForm." + Form.Name, Form.Synonym, False, PictureLib.Form);
	EndDo;

	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	FillMetadataObjectForms(Metadata.FilterCriteria, "FilterCriterion", NStr("ru = 'Критерий отбора'; en = 'Filter criterion'; pl = 'Kryterium filtrowania';es_ES = 'Criterio del filtro';es_CO = 'Criterio del filtro';tr = 'Filtre kriteri';it = 'Criterio di filtro';de = 'Filterkriterium'"),
		StandardFormNames, PictureLib.FilterCriterion, FormsList);
		
	StandardFormNames = New ValueList;
	FillMetadataObjectForms(Metadata.SettingsStorages, "SettingsStorage", NStr("ru = 'Хранилище настроек'; en = 'Settings storage'; pl = 'Przechowywania ustawień';es_ES = 'Almacenamiento de configuraciones';es_CO = 'Almacenamiento de configuraciones';tr = 'Ayarlar depolama alanı';it = 'Memorizzazione delle impostazioni';de = 'Speicherung der Einstellungen'"),
		StandardFormNames, PictureLib.SettingsStorage, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("FolderForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm", "ChoiceForm");
	StandardFormNames.Add("FolderChoiceForm", "FolderChoiceForm");
	FillMetadataObjectForms(Metadata.Catalogs, "Catalog", NStr("ru = 'Справочник'; en = 'Catalog'; pl = 'Katalog';es_ES = 'Catálogo';es_CO = 'Catálogo';tr = 'Katalog';it = 'Anagrafica';de = 'Katalog'"),
		StandardFormNames, PictureLib.Catalog, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm", "ChoiceForm");
	FillMetadataObjectForms(Metadata.Documents, "Document", NStr("ru = 'Документ'; en = 'Document'; pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"),
		StandardFormNames, PictureLib.Document, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	FillMetadataObjectForms(Metadata.DocumentJournals, "DocumentJournal", NStr("ru = 'Журнал документов'; en = 'Document journal'; pl = 'Dziennik dokumentów';es_ES = 'Diario de documentos';es_CO = 'Diario de documentos';tr = 'Belge günlüğü';it = 'Registro documenti';de = 'Dokument Journal'"),
		StandardFormNames, PictureLib.DocumentJournal, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm", "ChoiceForm");
	FillMetadataObjectForms(Metadata.Enums, "Enum", NStr("ru = 'Перечисление'; en = 'Enumeration'; pl = 'Enum';es_ES = 'Enumeración';es_CO = 'Enumeración';tr = 'Sıralama';it = 'Enumerazione';de = 'Aufzählung'"),
		StandardFormNames, PictureLib.Enum, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	StandardFormNames.Add("SettingsForm");
	StandardFormNames.Add("VariantForm");
	FillMetadataObjectForms(Metadata.Reports, "Report", NStr("ru = 'Отчет'; en = 'Report'; pl = 'Deklaracja';es_ES = 'Informe';es_CO = 'Informe';tr = 'Rapor';it = 'Report';de = 'Bericht'"),
		StandardFormNames, PictureLib.Report, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("Form");
	FillMetadataObjectForms(Metadata.DataProcessors, "DataProcessor", NStr("ru = 'Обработка'; en = 'Data processor'; pl = 'Procesor danych';es_ES = 'Procesador de datos';es_CO = 'Procesador de datos';tr = 'Veri işlemcisi';it = 'Processore dati';de = 'Daten Prozessor'"),
		StandardFormNames, PictureLib.DataProcessor, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("FolderForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm", "ChoiceForm");
	StandardFormNames.Add("FolderChoiceForm", "FolderChoiceForm");
	FillMetadataObjectForms(Metadata.ChartsOfCharacteristicTypes, "ChartOfCharacteristicTypes", NStr("ru = 'План видов характеристик'; en = 'Chart of characteristic types'; pl = 'Plan rodzajów charakterystyk';es_ES = 'Diagrama de los tipos de características';es_CO = 'Diagrama de los tipos de características';tr = 'Özellik türü listesi';it = 'Grafico dei tipi caratteristici';de = 'Diagramm von charakteristischen Typen'"),
		StandardFormNames, PictureLib.ChartOfCharacteristicTypes, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm", "ChoiceForm");
	FillMetadataObjectForms(Metadata.ChartsOfAccounts, "ChartOfAccounts", NStr("ru = 'План счетов'; en = 'Chart of accounts'; pl = 'Plan kont';es_ES = 'Diagrama primario de las cuentas';es_CO = 'Diagrama primario de las cuentas';tr = 'Hesap planı';it = 'Piano dei conti';de = 'Kontenplan'"),
		StandardFormNames, PictureLib.ChartOfAccounts, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm", "ChoiceForm");
	FillMetadataObjectForms(Metadata.ChartsOfCalculationTypes, "ChartOfCalculationTypes", NStr("ru = 'План видов расчета'; en = 'Chart of calculation types'; pl = 'Plan typów obliczeń';es_ES = 'Diagrama de los tipos de cálculos';es_CO = 'Diagrama de los tipos de cálculos';tr = 'Hesaplama türleri çizelgesi';it = 'Piano dei tipi di calcolo';de = 'Diagramm der Berechnungstypen'"),
		StandardFormNames, PictureLib.ChartOfCalculationTypes, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("RecordForm");
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.InformationRegisters, "InformationRegister", NStr("ru = 'Регистр сведений'; en = 'Information register'; pl = 'Rejestru informacji';es_ES = 'Registro de información';es_CO = 'Registro de información';tr = 'Bilgi kaydı';it = 'Registro informazioni';de = 'Informationsregister'"),
		StandardFormNames, PictureLib.InformationRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.AccumulationRegisters, "AccumulationRegister", NStr("ru = 'Регистр накопления'; en = 'Accumulation register'; pl = 'Rejestru akumulacji';es_ES = 'Registro de acumulación';es_CO = 'Registro de acumulación';tr = 'Birikeç';it = 'Registro di accumulo';de = 'Akkumulationsregister'"),
		StandardFormNames, PictureLib.AccumulationRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.AccountingRegisters, "AccountingRegister", NStr("ru = 'Регистр бухгалтерии'; en = 'Accounting register'; pl = 'Rejestr księgowy';es_ES = 'Registro de contabilidad';es_CO = 'Registro de contabilidad';tr = 'Muhasebe kaydı';it = 'Registro contabile';de = 'Buchhaltungsregister'"),
		StandardFormNames, PictureLib.AccountingRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.CalculationRegisters, "CalculationRegister", NStr("ru = 'Регистр расчета'; en = 'Calculation register'; pl = 'Rejestr kalkulacji';es_ES = 'Registro de cálculos';es_CO = 'Registro de cálculos';tr = 'Hesaplama kaydı';it = 'Registro di calcolo';de = 'Berechnungsregister'"),
		StandardFormNames, PictureLib.CalculationRegister, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm", "ChoiceForm");
	FillMetadataObjectForms(Metadata.BusinessProcesses, "BusinessProcess", NStr("ru = 'Бизнес-процесс'; en = 'Business process'; pl = 'Proces biznesowy';es_ES = 'Proceso de negocio';es_CO = 'Proceso de negocio';tr = 'İş süreci';it = 'Processo di business';de = 'Geschäftsprozess'"),
		StandardFormNames, PictureLib.BusinessProcess, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("ObjectForm");
	StandardFormNames.Add("ListForm");
	StandardFormNames.Add("ChoiceForm", "ChoiceForm");
	FillMetadataObjectForms(Metadata.Tasks, "Task", NStr("ru = 'Задача'; en = 'Task'; pl = 'Zadanie';es_ES = 'Tarea';es_CO = 'Tarea';tr = 'Görev';it = 'Compito';de = 'Aufgabe'"),
		StandardFormNames, PictureLib.Task, FormsList);
	
	StandardFormNames = New ValueList;
	StandardFormNames.Add("RecordForm");
	StandardFormNames.Add("ListForm");
	FillMetadataObjectForms(Metadata.ExternalDataSources, "ExternalDataSource", NStr("ru = 'Внешние источники данных'; en = 'External data sources'; pl = 'Zewnętrzne źródła danych';es_ES = 'Fuentes de datos externos';es_CO = 'Fuentes de datos externos';tr = 'Dış veri kaynakları';it = 'Fonti di dati esterne';de = 'Externe Datenquellen'"),
		StandardFormNames, PictureLib.ExternalDataSourceTable, FormsList);

	Return FormsList;
EndFunction

// Returns a settings list for the forms specified in the FormList parameter and for the user specified in the UserName parameter.
//
Function FormSettingsList(FormsList, Username)
	
	Result = New ValueTable;
	Result.Columns.Add("Value",      New TypeDescription("String"));
	Result.Columns.Add("Presentation", New TypeDescription("String"));
	Result.Columns.Add("Check",       New TypeDescription("Boolean"));
	Result.Columns.Add("Picture",      New TypeDescription("Picture"));
	Result.Columns.Add("KeysList",  New TypeDescription("ValueList"));
	
	ResultString = Undefined;
	FormDetails    = Undefined;
	
	Settings = ReadSettingsFromStorage(SystemSettingsStorage, Username);
	
	CurrentFormName = "";
	For Each Setting In Settings Do
		ObjectKey  = Setting.ObjectKey;
		SettingsKey = Setting.SettingsKey;
		ObjectKeyParts = StrSplit(ObjectKey, "/");
		If ObjectKeyParts.Count() < 2 Then
			Continue;
		EndIf;
		
		NameParts = StrSplit(ObjectKeyParts[0], ".", False);
		If NameParts.Count() > 4 Then
			FormName = NameParts[0] + "." + NameParts[1] + "." + NameParts[2] + "." + NameParts[3];
		Else
			FormName = ObjectKeyParts[0];
		EndIf;
		If ValueIsFilled(FormName) AND FormName = CurrentFormName Then
			ResultString.KeysList.Add(ObjectKey, SettingsKey, FormDetails.Check);
			Continue;
		EndIf;
		
		FormDetails = FormsList.FindByValue(FormName);
		If FormDetails = Undefined Then
			Continue;
		EndIf;
		
		ResultString = Result.Add();
		ResultString.Value      = FormDetails.Value;
		ResultString.Presentation = FormDetails.Presentation;
		ResultString.Check       = FormDetails.Check;
		ResultString.Picture      = FormDetails.Picture;
		ResultString.KeysList.Add(ObjectKey, SettingsKey, FormDetails.Check);
		
		CurrentFormName = FormName;
	EndDo;
	
	Return Result;
	
EndFunction

Procedure FillMetadataObjectForms(MetadataObjectList, MetadataObjectType,
	MetadataObjectPresentation, StandardFormNames, Picture, FormsList)
	
	For Each Object In MetadataObjectList Do
		
		If MetadataObjectType = "ExternalDataSource" Then
			FillExternalDataSourceForms(Object, MetadataObjectType, MetadataObjectPresentation, Picture, FormsList);
			Continue;
		EndIf;
		
		If Not AccessRight("View", Object) Then
			Continue;
		EndIf;
		
		NamePrefix = MetadataObjectType + "." + Object.Name;
		PresentationPrefix = Object.Synonym + ".";
		
		For Each Form In Object.Forms Do
			FormPresentationAndMark = FormPresentation(Object, Form, MetadataObjectType);
			FormPresentation = FormPresentationAndMark.FormName;
			Mark = FormPresentationAndMark.CanOpenForm;
			FormsList.Add(NamePrefix + ".Form." + Form.Name, PresentationPrefix + FormPresentation, Mark, Picture);
		EndDo;
		
		For Each StandardFormName In StandardFormNames Do
			
			Form = Object["Default" + StandardFormName.Value];
			If Form = Undefined Then
				FormName = ?(ValueIsFilled(StandardFormName.Presentation), StandardFormName.Presentation, StandardFormName.Value);
				FormPresentationAndMark = AutogeneratedFormPresentation(Object, StandardFormName.Value, MetadataObjectType);
				FormPresentation = FormPresentationAndMark.FormName;
				Mark = FormPresentationAndMark.CanOpenForm;
				FormsList.Add(NamePrefix + "." + FormName, PresentationPrefix + FormPresentation, Mark, Picture);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure FillExternalDataSourceForms(Object, MetadataObjectType, 
	MetadataObjectPresentation, Picture, FormsList)
	
	For Each Table In Object.Tables Do
		
		NamePrefix = MetadataObjectType + "." + Object.Name + ".Table.";
		PresentationPrefix = Table.Synonym + ".";
		
		For Each Form In Table.Forms Do
			FormPresentation = FormPresentation(Table, Form, MetadataObjectType).FormName;
			FormsList.Add(NamePrefix + Table.Name + ".Form." + Form.Name, PresentationPrefix + FormPresentation, False, Picture);
		EndDo;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions needed to copy and delete all user settings.

// Deletes user settings from the storage.
//
// Parameters:
// SettingsToClear - Array, where an array element is a type of settings to clear.
//                       For example, ReportSettings or AppearanceSettings.
// Sources - Array, where an array element is Catalog.UserRef. An array of users whose settings have 
//             to be cleared.
//
Procedure DeleteUserSettings(SettingsToClear, Sources, UserReportOptionTable = Undefined) Export
	
	SettingsItemStorageMap = New Map;
	SettingsItemStorageMap.Insert("ReportSettings", ReportsUserSettingsStorage);
	SettingsItemStorageMap.Insert("InterfaceSettings", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("FormData", FormDataSettingsStorage);
	SettingsItemStorageMap.Insert("PersonalSettings", CommonSettingsStorage);
	SettingsItemStorageMap.Insert("Favorites", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("PrintSettings", SystemSettingsStorage);
	
	For Each SettingsItemToClear In SettingsToClear Do
		SettingsManager = SettingsItemStorageMap[SettingsItemToClear];
		
		For Each Source In Sources Do
			
			If SettingsItemToClear = "OtherUserSettings" Then
				// Getting user settings.
				UserInfo = New Structure;
				UserInfo.Insert("UserRef", Source);
				UserInfo.Insert("InfobaseUserName", IBUserName(Source));
				OtherUserSettings = New Structure;
				UsersInternal.OnGetOtherUserSettings(UserInfo, OtherUserSettings);
				Keys = New ValueList;
				OtherSettingsArray = New Array;
				If OtherUserSettings.Count() <> 0 Then
					
					For Each OtherSetting In OtherUserSettings Do
						OtherSettingsStructure = New Structure;
						If OtherSetting.Key = "QuickAccessSetting" Then
							SettingsList = OtherSetting.Value.SettingsList;
							For Each Item In SettingsList Do
								Keys.Add(Item.Object, Item.ID);
							EndDo;
							OtherSettingsStructure.Insert("SettingID", "QuickAccessSetting");
							OtherSettingsStructure.Insert("SettingValue", Keys);
						Else
							OtherSettingsStructure.Insert("SettingID", OtherSetting.Key);
							OtherSettingsStructure.Insert("SettingValue", OtherSetting.Value.SettingsList);
						EndIf;
						
						UsersInternal.OnDeleteOtherUserSettings(UserInfo, OtherSettingsStructure);
					EndDo;
					
				EndIf;
				
				Continue;
			EndIf;
			
			InfobaseUser = IBUserName(Source);
			
			If SettingsItemToClear = "ReportSettings" Then
				
				If UserReportOptionTable = Undefined
				 Or Sources.Count() <> 1 Then
					
					UserReportOptionTable = UserReportOptions(InfobaseUser);
				EndIf;
				
				For Each ReportOption In UserReportOptionTable Do
					
					StandardProcessing = True;
					
					SSLSubsystemsIntegration.OnDeleteUserReportOptions(ReportOption,
						InfobaseUser, StandardProcessing);
					
					If StandardProcessing Then
						ReportsVariantsStorage.Delete(ReportOption.ObjectKey, ReportOption.VariantKey, InfobaseUser);
					EndIf;
					
				EndDo;
				
			EndIf;
			
			// Clearing dynamic list settings.
			If SettingsItemToClear = "InterfaceSettings" Then
				SettingsFromStorage = ReadSettingsFromStorage(DynamicListsUserSettingsStorage, InfobaseUser);
				DeleteSettings(DynamicListsUserSettingsStorage, SettingsFromStorage, InfobaseUser);
			EndIf;
			
			SettingsFromStorage = SettingsList(InfobaseUser, SettingsManager, SettingsItemToClear);
			DeleteSettings(SettingsManager, SettingsFromStorage, InfobaseUser);
			
			UsersInternal.SetInitialSettings(InfobaseUser, 
				TypeOf(Source) = Type("CatalogRef.ExternalUsers"));
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure DeleteSettings(SettingsManager, SettingsFromStorage, Username)
	
	For Each Setting In SettingsFromStorage Do
		ObjectKey = Setting.ObjectKey;
		SettingsKey = Setting.SettingsKey;
		SettingsManager.Delete(ObjectKey, SettingsKey, Username);
	EndDo;
	
EndProcedure

Function CopyUsersSettings(UserSourceRef, UsersDestination, SettingsToCopy,
										NotCopiedReportSettings = Undefined) Export
	
	SettingsItemStorageMap = New Map;
	SettingsItemStorageMap.Insert("ReportSettings", ReportsUserSettingsStorage);
	SettingsItemStorageMap.Insert("InterfaceSettings", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("FormData", FormDataSettingsStorage);
	SettingsItemStorageMap.Insert("PersonalSettings", CommonSettingsStorage);
	SettingsItemStorageMap.Insert("Favorites", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("PrintSettings", SystemSettingsStorage);
	SettingsItemStorageMap.Insert("ReportsOptions", ReportsVariantsStorage);
	HasSettings = False;
	ReportOptionTable = Undefined;
	SourceUser = IBUserName(UserSourceRef);
	
	SettingsRecipients = New Array;
	For Each Item In UsersDestination Do
		SettingsRecipients.Add(IBUserName(Item));
	EndDo;
	
	// Getting user settings.
	UserInfo = New Structure;
	UserInfo.Insert("UserRef", UserSourceRef);
	UserInfo.Insert("InfobaseUserName", SourceUser);
	OtherUserSettings = New Structure;
	UsersInternal.OnGetOtherUserSettings(UserInfo, OtherUserSettings);
	Keys = New ValueList;
	OtherSettingsArray = New Array;
	If OtherUserSettings.Count() <> 0 Then
		
		For Each OtherSetting In OtherUserSettings Do
			OtherSettingsStructure = New Structure;
			If OtherSetting.Key = "QuickAccessSetting" Then
				SettingsList = OtherSetting.Value.SettingsList;
				For Each Item In SettingsList Do
					Keys.Add(Item.Object, Item.ID);
				EndDo;
				OtherSettingsStructure.Insert("SettingID", "QuickAccessSetting");
				OtherSettingsStructure.Insert("SettingValue", Keys);
			Else
				OtherSettingsStructure.Insert("SettingID", OtherSetting.Key);
				OtherSettingsStructure.Insert("SettingValue", OtherSetting.Value.SettingsList);
			EndIf;
			OtherSettingsArray.Add(OtherSettingsStructure);
		EndDo;
		
	EndIf;
	
	For Each SettingsItemToCopy In SettingsToCopy Do
		SettingsManager = SettingsItemStorageMap[SettingsItemToCopy];
		
		If SettingsItemToCopy = "OtherUserSettings" Then
			For Each DestinationUser In UsersDestination Do
				UserInfo = New Structure;
				UserInfo.Insert("UserRef", DestinationUser);
				UserInfo.Insert("InfobaseUserName", IBUserName(DestinationUser));
				For Each ArrayElement In OtherSettingsArray Do
					UsersInternal.OnSaveOtherUserSettings(UserInfo, ArrayElement);
				EndDo;
			EndDo;
			Continue;
		EndIf;
		
		If SettingsItemToCopy = "ReportSettings" Then
			
			If TypeOf(SettingsItemStorageMap["ReportsOptions"]) = Type("StandardSettingsStorageManager") Then
				ReportOptionTable = UserReportOptions(SourceUser);
				ReportOptionKeyAndTypeTable = GetReportOptionKeys(ReportOptionTable);
				SettingsToCopy.Add("ReportsOptions");
			EndIf;
			
		EndIf;
		
		If SettingsItemToCopy = "InterfaceSettings" Then
			DynamicListsSettings = ReadSettingsFromStorage(DynamicListsUserSettingsStorage, SourceUser);
			CopyDynamicListSettings(SettingsRecipients, SourceUser, DynamicListsSettings);
		EndIf;
		
		SettingsFromStorage = SettingsList(
			SourceUser, SettingsManager, SettingsItemToCopy, ReportOptionKeyAndTypeTable, True);
		
		If SettingsFromStorage.Count() <> 0 Then
			HasSettings = True;
		EndIf;
		
		For Each DestinationUser In UsersDestination Do
			CopySettings(
				SettingsManager, SettingsFromStorage, SourceUser, DestinationUser, NotCopiedReportSettings);
			ReportOptionTable = Undefined;
		EndDo;
		
	EndDo;
	
	Return HasSettings;
	
EndFunction

Function SettingsList(Username, SettingsManager, 
						SettingsItemToCopy, ReportOptionKeyAndTypeTable = Undefined, ForCopying = False)
	
	GetFavorites = False;
	GetPrintSettings = False;
	If SettingsItemToCopy = "Favorites" Then
		GetFavorites = True;
	EndIf;
	
	If SettingsItemToCopy = "PrintSettings" Then
		GetPrintSettings = True;
	EndIf;
	
	SettingsTable = New ValueTable;
	SettingsTable.Columns.Add("ObjectKey");
	SettingsTable.Columns.Add("SettingsKey");
	
	Filter = New Structure;
	Filter.Insert("User", Username);
	
	SettingsSelection = SettingsManager.Select(Filter);
	
	Ignore = False;
	While NextSettingsItem(SettingsSelection, Ignore) Do
		
		If Ignore Then
			Continue;
		EndIf;
		
		If Not GetFavorites
			AND StrFind(SettingsSelection.ObjectKey, "UserWorkFavorites") <> 0 Then
			Continue;
		ElsIf GetFavorites Then
			
			If StrFind(SettingsSelection.ObjectKey, "UserWorkFavorites") = 0 Then
				Continue;
			ElsIf StrFind(SettingsSelection.ObjectKey, "UserWorkFavorites") <> 0 Then
				AddRowToValueTable(SettingsTable, SettingsSelection);
				Continue;
			EndIf;
			
		EndIf;
		
		If Not GetPrintSettings
			AND StrFind(SettingsSelection.ObjectKey, "SpreadsheetDocumentPrintSettings") <> 0 Then
			Continue;
		ElsIf GetPrintSettings Then
			
			If StrFind(SettingsSelection.ObjectKey, "SpreadsheetDocumentPrintSettings") = 0 Then
				Continue;
			ElsIf StrFind(SettingsSelection.ObjectKey, "SpreadsheetDocumentPrintSettings") <> 0 Then
				AddRowToValueTable(SettingsTable, SettingsSelection);
				Continue;
			EndIf;
			
		EndIf;
		
		If ReportOptionKeyAndTypeTable <> Undefined Then
			
			FoundReportOption = ReportOptionKeyAndTypeTable.Find(SettingsSelection.ObjectKey, "VariantKey");
			If FoundReportOption <> Undefined Then
				
				If Not FoundReportOption.Check Then
					Continue;
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If ForCopying AND SkipSettingsItem(SettingsSelection.ObjectKey, SettingsSelection.SettingsKey) Then
			Continue;
		EndIf;
		
		AddRowToValueTable(SettingsTable, SettingsSelection);
	EndDo;
	
	Return SettingsTable;
	
EndFunction

Function NextSettingsItem(SettingsSelection, Ignore)
	
	Try 
		Ignore = False;
		Return SettingsSelection.Next();
	Except
		Ignore = True;
		Return True;
	EndTry;
	
EndFunction

Procedure CopySettings(SettingsManager, SettingsTable, SourceUser,
								DestinationUser, NotCopiedReportSettings)
	
	DestinationIBUser = IBUserName(DestinationUser);
	CurrentUser = Undefined;
	
	SettingsQueue = New Map;
	IsSystemSettingsStorage = (SettingsManager = SystemSettingsStorage);
	
	For Each Setting In SettingsTable Do
		
		ObjectKey = Setting.ObjectKey;
		SettingKey = Setting.SettingsKey;
		
		If IsSystemSettingsStorage Then
			SettingsQueue.Insert(ObjectKey, SettingKey);
		EndIf;
		
		If SettingsManager = ReportsUserSettingsStorage
			Or SettingsManager = ReportsVariantsStorage Then
			
			AvailableReportArray = ReportsAvailableToUser(DestinationIBUser);
			ReportKey = StrSplit(ObjectKey, "/", False);
			If AvailableReportArray.Find(ReportKey[0]) = Undefined Then
				
				If SettingsManager = ReportsUserSettingsStorage
					AND NotCopiedReportSettings <> Undefined Then
					
					If CurrentUser = Undefined Then
						TableRow = NotCopiedReportSettings.Add();
						TableRow.User = String(DestinationUser.Description);
						CurrentUser = String(DestinationUser.Description);
					EndIf;
					
					If TableRow.ReportsList.FindByValue(ReportKey[0]) = Undefined Then
						TableRow.ReportsList.Add(ReportKey[0]);
					EndIf;
					
				EndIf;
				
				Continue;
			EndIf;
			
		EndIf;
		
		Try
			Value = SettingsManager.Load(ObjectKey, SettingKey, , SourceUser);
		Except
			Continue;
		EndTry;
		SettingsDetails = SettingsManager.GetDescription(ObjectKey, SettingKey, SourceUser);
		SettingsManager.Save(ObjectKey, SettingKey, Value,
			SettingsDetails, DestinationIBUser);
	EndDo;
	
	If Not Common.FileInfobase()
		AND SettingsQueue.Count() > 0 Then
		FillSettingsQueue(SettingsQueue, DestinationIBUser);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions needed to copy and delete the selected setting settings.

// Copies user report settings.
// 
// Parameters:
// SourceUser - String - infobase source user for copying the settings.
// UsersDestination - an array of UserRef elements - users that need to copy the selected settings.
//                        
// SettingsToCopyArray - Array - array element - ValueList that contains security keys of selected 
//                                         settings.
//
Procedure CopyReportAndPersonalSettings(SettingsManager, SourceUser,
		UsersDestination, SettingsToCopyArray, NotCopiedReportSettings = Undefined) Export
	
	For Each DestinationUser In UsersDestination Do
		CurrentUser = Undefined;
		
		For Each Item In SettingsToCopyArray Do
				
			For Each SettingsItem In Item Do
				
				SettingsKey = SettingsItem.Presentation;
				ObjectKey = SettingsItem.Value;
				If SkipSettingsItem(ObjectKey, SettingsKey) Then
					Continue;
				EndIf;
				Setting = SettingsManager.Load(ObjectKey, SettingsKey, , SourceUser);
				SettingDescription = SettingsManager.GetDescription(ObjectKey, SettingsKey, SourceUser);
				
				If Setting <> Undefined Then
					
					DestinationIBUser = IBUserName(DestinationUser);
					
					If SettingsManager = ReportsUserSettingsStorage Then
						AvailableReportArray = ReportsAvailableToUser(DestinationIBUser);
						ReportKey = StrSplit(ObjectKey, "/", False);
						
						If AvailableReportArray.Find(ReportKey[0]) = Undefined Then
							
							If CurrentUser = Undefined Then
								TableRow = NotCopiedReportSettings.Add();
								TableRow.User = DestinationUser.Description;
								CurrentUser = DestinationUser.Description;
							EndIf;
							
							If TableRow.ReportsList.FindByValue(ReportKey[0]) = Undefined Then
								TableRow.ReportsList.Add(ReportKey[0]);
							EndIf;
								
							Continue;
						EndIf;
						
					EndIf;
					
					SettingsManager.Save(ObjectKey, SettingsKey, Setting, SettingDescription, DestinationIBUser);
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// Copies the interface settings.
// 
// Parameters:
// SourceUser - String - infobase source user for copying the settings.
// UsersDestination - an array of UserRef elements - users that need to copy the selected settings.
//                        
// SettingsToCopyArray - Array - array element - ValueList that contains security keys of selected 
//                                         settings.
//
Procedure CopyInterfaceSettings(SourceUser, UsersDestination, SettingsToCopyArray) Export
	
	SettingsQueue    = New Map;
	SettingsRecipients = New Array;
	ProcessedKeys  = New Map;
	
	For Each Item In UsersDestination Do
		SettingsRecipients.Add(IBUserName(Item));
	EndDo;
	
	DynamicListsSettings = ReadSettingsFromStorage(DynamicListsUserSettingsStorage, SourceUser);
	
	For Each Item In SettingsToCopyArray Do
		
		For Each SettingsItem In Item Do
			SettingsKey = SettingsItem.Presentation;
			ObjectKey  = SettingsItem.Value;
			
			SettingsQueue.Insert(ObjectKey, SettingsKey);
			
			If SettingsKey = "Interface"
				Or SettingsKey = "OtherItems" Then
				CopyDesktopSettings(ObjectKey, SourceUser, SettingsRecipients);
				Continue;
			EndIf;
			
			// Copying dynamic list settings.
			ObjectKeyParts = StrSplit(ObjectKey, "/");
			ObjectName = ObjectKeyParts[0];
			If ProcessedKeys[ObjectName] = Undefined Then
				SearchParameters = New Structure;
				SearchParameters.Insert("ObjectKey", ObjectName);
				SearchResult = DynamicListsSettings.FindRows(SearchParameters);
				CopyDynamicListSettings(SettingsRecipients, SourceUser, SearchResult);
				ProcessedKeys.Insert(ObjectName, True);
			EndIf;
			
			// Copy settings.
			Setting = SystemSettingsStorage.Load(ObjectKey, SettingsKey, , SourceUser);
			If Setting <> Undefined Then
				
				For Each DestinationIBUser In SettingsRecipients Do
					SystemSettingsStorage.Save(ObjectKey, SettingsKey, Setting, , DestinationIBUser);
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If Not Common.FileInfobase() Then
		For Each SettingsRecipient In SettingsRecipients Do
			FillSettingsQueue(SettingsQueue, SettingsRecipient);
		EndDo;
	EndIf;
	
EndProcedure

Procedure CopyDynamicListSettings(SettingsRecipients, SourceUser, Settings)
	
	For Each Setting In Settings Do
		Value = DynamicListsUserSettingsStorage.Load(
			Setting.ObjectKey,
			Setting.SettingsKey, ,
			SourceUser);
		If Value <> Undefined Then
			For Each DestinationIBUser In SettingsRecipients Do
				SettingsDetails = New SettingsDescription;
				SettingsDetails.Presentation = Setting.Presentation;
				
				DynamicListsUserSettingsStorage.Save(
					Setting.ObjectKey,
					Setting.SettingsKey,
					Value,
					SettingsDetails,
					DestinationIBUser);
			EndDo;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillSettingsQueue(SettingsQueue, SettingsRecipient)
	
	PreviousSettings = CommonSettingsStorage.Load("SettingsQueue", "NotAppliedSettings",, SettingsRecipient);
	If TypeOf(PreviousSettings) = Type("ValueStorage") Then
		PreviousSettings = PreviousSettings.Get();
		If TypeOf(PreviousSettings) = Type("Map") Then
			CommonClientServer.SupplementMap(SettingsQueue, PreviousSettings, True);
		EndIf;
	EndIf;
	CommonSettingsStorage.Save(
		"SettingsQueue",
		"NotAppliedSettings",
		New ValueStorage(SettingsQueue, New Deflation(9)),
		,
		SettingsRecipient);
	
EndProcedure

Procedure CopyDesktopSettings(ObjectKey, SourceUser, SettingsRecipients)
	
	Setting = SystemSettingsStorage.Load(ObjectKey, "", , SourceUser);
	If Setting <> Undefined Then
		
		For Each DestinationIBUser In SettingsRecipients Do
			SystemSettingsStorage.Save(ObjectKey, "", Setting, , DestinationIBUser);
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure DeleteSettingsForSelectedUsers(Users, SettingsForDeletionArray, StorageDescription) Export
	
	For Each User In Users Do
		InfobaseUser = IBUserName(User);
		
		UserInfo = New Structure;
		UserInfo.Insert("InfobaseUserName", InfobaseUser);
		UserInfo.Insert("UserRef", User);
		DeleteSelectedSettings(UserInfo, SettingsForDeletionArray, StorageDescription);
	EndDo;
	
EndProcedure

Procedure DeleteSelectedSettings(UserInfo, SettingsForDeletionArray, StorageName) Export
	
	InfobaseUser     = UserInfo.InfobaseUserName;
	UserRef = UserInfo.UserRef;
	
	SettingsManager = SettingsStorageByName(StorageName);
	If StorageName = "ReportsUserSettingsStorage" Or StorageName = "CommonSettingsStorage" Then
		
		For Each Item In SettingsForDeletionArray Do
			
			For Each Setting In Item Do
				SettingsManager.Delete(Setting.Value, Setting.Presentation, InfobaseUser);
			EndDo;
			
		EndDo;
		
	ElsIf StorageName = "SystemSettingsStorage" Then
		
		SetInitialSettings = False;
		ProcessedKeys = New Map;
		
		For Each Item In SettingsForDeletionArray Do
			
			For Each Setting In Item Do
				
				If Setting.Presentation = "Interface" Or Setting.Presentation = "OtherItems" Then
					
					SettingsManager.Delete(Setting.Value, , InfobaseUser);
					
					If Setting.Value = "Common/ClientSettings" 
						Or Setting.Value = "Common/SectionsPanel/CommandInterfaceSettings" 
						Or Setting.Value = "Common/ClientApplicationInterfaceSettings" Then
						
						SetInitialSettings = True;
						
					EndIf;
					
				Else
					// Deleting dynamic list settings.
					ObjectKeyParts = StrSplit(Setting.Value, "/");
					ObjectName = ObjectKeyParts[0];
					If ProcessedKeys[ObjectName] = Undefined Then
						FilterParameters = New Structure;
						FilterParameters.Insert("ObjectKey", ObjectName);
						FilterParameters.Insert("User", InfobaseUser);
						SettingsSelection = DynamicListsUserSettingsStorage.Select(FilterParameters);
						While SettingsSelection.Next() Do
							DynamicListsUserSettingsStorage.Delete(SettingsSelection.ObjectKey, SettingsSelection.SettingsKey, InfobaseUser);
						EndDo;
						ProcessedKeys.Insert(ObjectName, True);
					EndIf;
					
					SettingsManager.Delete(Setting.Value, Setting.Presentation, InfobaseUser);
					
				EndIf;
				
			EndDo;
			
		EndDo;
		
		If SetInitialSettings Then
			UsersInternal.SetInitialSettings(InfobaseUser, 
				TypeOf(UserRef) = Type("CatalogRef.ExternalUsers"));
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure DeleteReportOptions(ReportOptionArray, UserReportOptionTable, InfobaseUser) Export
	
	For Each Setting In ReportOptionArray Do
		
		ObjectKey = StrSplit(Setting[0].Value, "/", False);
		ReportKey = ObjectKey[0];
		OptionKey = ObjectKey[1];
		
		FilterParameters = New Structure("VariantKey", OptionKey);
		FoundReportOption = UserReportOptionTable.FindRows(FilterParameters);
		
		If FoundReportOption.Count() = 0 Then
			Continue;
		EndIf;
		
		StandardProcessing = True;
		
		SSLSubsystemsIntegration.OnDeleteUserReportOptions(FoundReportOption[0],
			InfobaseUser, StandardProcessing);
		
		If StandardProcessing Then
			ReportsVariantsStorage.Delete(ReportKey, OptionKey, InfobaseUser);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CopyReportOptions(ReportOptionArray, UserReportOptionTable,
										InfobaseUser, RecipientUsers) Export
		
		If TypeOf(InfobaseUser) <> Type("String") Then
			InfobaseUser = IBUserName(InfobaseUser);
		EndIf;
		
		For Each Setting In ReportOptionArray Do
		
		ObjectKey = StrSplit(Setting[0].Value, "/", False);
		ReportKey = ObjectKey[0];
		OptionKey = ObjectKey[1];
		
		FilterParameters = New Structure("VariantKey", OptionKey);
		FoundReportOption = UserReportOptionTable.FindRows(FilterParameters);
		
		If FoundReportOption[0].StandardProcessing Then
			
			Try
			Value = ReportsVariantsStorage.Load(ReportKey, OptionKey, , InfobaseUser);
			Except
				Continue;
			EndTry;
			SettingDescription = ReportsVariantsStorage.GetDescription(ReportKey, OptionKey, InfobaseUser);
			
			For Each SettingsRecipient In RecipientUsers Do
				SettingsRecipient = IBUserName(SettingsRecipient);
				ReportsVariantsStorage.Save(ReportKey, OptionKey, Value, SettingDescription, SettingsRecipient);
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for getting a list of users and user groups.

// Gets the list of users from the Users catalog, filtering out inactive users, shared users with an 
// enabled separator, and users with blank IDs.
// 
// Parameters:
// SourceUser - CatalogRef - a user to be removed from the resulting user table.
// UsersTable - ValueTable - a table to which filtered users are written.
// ExternalUser - Boolean - if True, users are selected from the ExternalUsers catalog.
//
Function UsersToCopy(SourceUser, UsersTable, ExternalUser, Clearing = False) Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Parameters.Insert("SourceUser", SourceUser);
	Query.Parameters.Insert("UnspecifiedUser", Users.UnspecifiedUserRef());
	Query.Parameters.Insert("EmptyUniqueID",
		New UUID("00000000-0000-0000-0000-000000000000"));
	
	If Clearing Then
		Query.Text = AllUsersListQueryText(False, Clearing)
			+ Chars.LF + Chars.LF + "UNION ALL" + Chars.LF + Chars.LF
			+ AllUsersListQueryText(True, Clearing);
	Else
		Query.Text = AllUsersListQueryText(ExternalUser, Clearing);
	EndIf;
	
	BeginTransaction();
	Try
		UsersList = Query.Execute().Unload();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	For Each UserRef In UsersList Do
		UserTableRow = UsersTable.Add();
		UserTableRow.User = UserRef.User;
	EndDo;
	UsersTable.Sort("User Asc");
	
	Return UsersTable;
	
EndFunction

Function AllUsersListQueryText(ExternalUser, Clearing)
	
	QueryText =
	"SELECT
	|	Users.Ref AS User
	|FROM
	|	Catalog.Users AS Users
	|WHERE
	|	&ExceptInvalid
	|	AND &ExceptMarkedForDeletion
	|	AND &ExceptInternalUsers
	|	AND Users.Ref <> &SourceUser
	|	AND NOT(Users.IBUserID = &EmptyUniqueID
	|				AND Users.Ref <> &UnspecifiedUser)";
	
	If ExternalUser Then
		QueryText = StrReplace(QueryText, "Catalog.Users", "Catalog.ExternalUsers");
	EndIf;
	
	QueryText = StrReplace(QueryText, "&ExceptMarkedForDeletion",
		?(Clearing, "True", "NOT Users.DeletionMark"));
	
	QueryText = StrReplace(QueryText, "&ExceptInvalid",
		?(Clearing, "True", "NOT Users.Invalid"));
	
	QueryText = StrReplace(QueryText, "&ExceptInternalUsers",
		?(Clearing AND Not Common.DataSeparationEnabled() Or ExternalUser,
			"True", "NOT Users.Internal"));
	
	Return QueryText;
	
EndFunction

// Generates a user group value tree.
// 
// Parameters:
// GroupsTree - ValueTree - a tree that is populated with user groups.
// ExternalUser - Boolean - if True, users are selected from the ExternalUserGroups catalog.
Procedure FillGroupTree(GroupsTree, ExternalUser) Export
	
	GroupsArray = New Array;
	ParentGroupArray = New Array;
	GroupListAndFullComposition = UserGroups(ExternalUser);
	UserGroupList = GroupListAndFullComposition.UserGroupList;
	GroupsAndCompositionTable = GroupListAndFullComposition.GroupsAndCompositionTable;
	
	If ExternalUser Then
		EmptyGroup = Catalogs.ExternalUsersGroups.EmptyRef();
	Else
		EmptyGroup = Catalogs.UserGroups.EmptyRef();
	EndIf;
	
	GenerateFilter(UserGroupList, EmptyGroup, GroupsArray);
	
	While GroupsArray.Count() > 0 Do
		ParentGroupArray.Clear();
		
		For Each Folder In GroupsArray Do
			
			If Folder.Parent = EmptyGroup Then
				NewGroupRow = GroupsTree.Rows.Add();
				NewGroupRow.Group = Folder.Ref;
				GroupComposition = UserGroupComposition(Folder.Ref, ExternalUser);
				FullGroupComposition = UserGroupFullComposition(GroupsAndCompositionTable, Folder.Ref);
				NewGroupRow.Content = GroupComposition;
				NewGroupRow.FullComposition = FullGroupComposition;
				NewGroupRow.Picture = 3;
			Else
				ParentGroup = GroupsTree.Rows.FindRows(New Structure("Group", Folder.Parent), True);
				NewSubordinateGroupRow = ParentGroup[0].Rows.Add();
				NewSubordinateGroupRow.Group = Folder.Ref;
				GroupComposition = UserGroupComposition(Folder.Ref, ExternalUser);
				FullGroupComposition = UserGroupFullComposition(GroupsAndCompositionTable, Folder.Ref);
				NewSubordinateGroupRow.Content = GroupComposition;
				NewSubordinateGroupRow.FullComposition = FullGroupComposition;
				NewSubordinateGroupRow.Picture = 3;
			EndIf;
			
			ParentGroupArray.Add(Folder.Ref);
		EndDo;
		GroupsArray.Clear();
		
		For Each Item In ParentGroupArray Do
			GenerateFilter(UserGroupList, Item, GroupsArray);
		EndDo;
		
	EndDo;
	
EndProcedure

Function UserGroups(ExternalUser)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CatalogUserGroups.Ref AS Ref,
	|	CatalogUserGroups.Parent AS Parent
	|FROM
	|	Catalog.UserGroups AS CatalogUserGroups";
	If ExternalUser Then 
		Query.Text = StrReplace(Query.Text, "Catalog.UserGroups", "Catalog.ExternalUsersGroups");
	EndIf;
	
	UserGroupList = Query.Execute().Unload();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UserGroupCompositions.UsersGroup AS UsersGroup,
	|	UserGroupCompositions.User AS User
	|FROM
	|	InformationRegister.UserGroupCompositions AS UserGroupCompositions
	|
	|ORDER BY
	|	UsersGroup";
	
	UserGroupsComposition = Query.Execute().Unload();
	
	GroupsAndCompositionTable = UserGroupsFullComposition(UserGroupsComposition);
	
	Return New Structure("UserGroupList, GroupsAndCompositionTable",
							UserGroupList, GroupsAndCompositionTable);
EndFunction

Function UserGroupsFullComposition(UserGroupsComposition)
	
	GroupsAndCompositionTable = New ValueTable;
	GroupsAndCompositionTable.Columns.Add("Group");
	GroupsAndCompositionTable.Columns.Add("Content");
	GroupComposition = New ValueList;
	CurrentGroup = Undefined;
	
	For Each CompositionRow In UserGroupsComposition Do
		
		If TypeOf(CompositionRow.UsersGroup) = Type("CatalogRef.UserGroups")
			Or TypeOf(CompositionRow.UsersGroup) = Type("CatalogRef.ExternalUsersGroups") Then
			
			If CurrentGroup <> CompositionRow.UsersGroup 
				AND Not CurrentGroup = Undefined Then
				GroupsAndCompositionTableRow = GroupsAndCompositionTable.Add();
				GroupsAndCompositionTableRow.Group = CurrentGroup;
				GroupsAndCompositionTableRow.Content = GroupComposition.Copy();
				GroupComposition.Clear();
			EndIf;
			GroupComposition.Add(CompositionRow.User);
			
		CurrentGroup = CompositionRow.UsersGroup;
		EndIf;
		
	EndDo;
	
	GroupsAndCompositionTableRow = GroupsAndCompositionTable.Add();
	GroupsAndCompositionTableRow.Group = CurrentGroup;
	GroupsAndCompositionTableRow.Content = GroupComposition.Copy();
	
	Return GroupsAndCompositionTable;
EndFunction

Function UserGroupComposition(GroupRef, ExternalUser)
	
	GroupComposition = New ValueList;
	For Each Item In GroupRef.Content Do
		
		If ExternalUser Then
			GroupComposition.Add(Item.ExternalUser);
		Else
			GroupComposition.Add(Item.User);
		EndIf;
		
	EndDo;
	
	Return GroupComposition;
EndFunction

Function UserGroupFullComposition(GroupsAndCompositionTable, GroupRef)
	
	FullGroupComposition = GroupsAndCompositionTable.FindRows(New Structure("Group", GroupRef));
	If FullGroupComposition.Count() <> 0 Then
		Return FullGroupComposition[0].Content;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Generates an array of reports that are available to the specified user.
//
// Parameters:
//  InfobaseUser - String - name of the infobase user whose report access rights are checked.
//                                   
//
// Returns:
//   Result - Array - keys of reports available to the passed user.
//
Function ReportsAvailableToUser(DestinationUser)
	Result = New Array;
	
	SetPrivilegedMode(True);
	InfobaseUser = InfoBaseUsers.FindByName(DestinationUser);
	For Each ReportMetadata In Metadata.Reports Do
		
		If AccessRight("View", ReportMetadata, InfobaseUser) Then
			Result.Add("Report." + ReportMetadata.Name);
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

// Gets the name of an infobase user by a catalog reference.
// 
// Parameters:
// UserRef - CatalogRef - user that requires the name of an infobase user.
// 
//
// Returns
// String - name of the infobase user. If the infobase user is not found, it is Undefined.
// 
Function IBUserName(UserRef) Export
	
	SetPrivilegedMode(True);
	IBUserID = Common.ObjectAttributeValue(UserRef, "IBUserID");
	InfobaseUser = InfoBaseUsers.FindByUUID(IBUserID);
	
	If InfobaseUser <> Undefined Then
		Return InfobaseUser.Name;
	ElsIf UserRef = Users.UnspecifiedUserRef() Then
		Return "";
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function FormPresentation(Object, Form, MetadataObjectType)
	
	CanOpenForm = False;
	
	If MetadataObjectType = "FilterCriterion"
		Or MetadataObjectType = "DocumentJournal" Then
		
		If Form = Object.DefaultForm Then
			FormName = ListFormPresentation(Object);
			CanOpenForm = True;
		Else 
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "AccumulationRegister"
		Or MetadataObjectType = "AccountingRegister"
		Or MetadataObjectType = "CalculationRegister" Then
		
		If Form = Object.DefaultListForm Then
			FormName = ListFormPresentation(Object);
			CanOpenForm = True;
		Else 
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "InformationRegister" Then
		
		If Form = Object.DefaultRecordForm Then
			
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			
		ElsIf Form = Object.DefaultListForm Then
			FormName = ListFormPresentation(Object);
			CanOpenForm = True;
		Else 
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "Report"
		Or MetadataObjectType = "DataProcessor" Then
		
		If Form = Object.DefaultForm Then
			If Not IsBlankString(Object.ExtendedPresentation) Then
				FormName = Object.ExtendedPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			CanOpenForm = True;
		Else
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "SettingsStorage" Then
		FormName = Form.Synonym;
	ElsIf MetadataObjectType = "Enum" Then
		
		If Form = Object.DefaultListForm
			Or Form = Object.DefaultChoiceForm Then
			FormName = ListFormPresentation(Object);
			CanOpenForm = ?(Form = Object.DefaultListForm, True, False);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "Catalog"
		Or MetadataObjectType = "ChartOfCharacteristicTypes" Then
		
		If Form = Object.DefaultListForm
			Or Form = Object.DefaultChoiceForm
			Or Form = Object.DefaultFolderForm 
			Or Form = Object.DefaultFolderChoiceForm Then
			
			FormName = ListFormPresentation(Object);
			AddFormTypeToPresentation(Object, Form, FormName);
			CanOpenForm = ?(Form = Object.DefaultListForm, True, False);
			
		ElsIf Form = Object.DefaultObjectForm Then
			FormName = ObjectFormPresentation(Object);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	ElsIf MetadataObjectType = "ExternalDataSource" Then
		
		If Form = Object.DefaultListForm Then
			FormName = ListFormPresentation(Object);
			CanOpenForm = True;
		ElsIf Form = Object.DefaultRecordForm Then
			
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation ;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			
		ElsIf Form = Object.DefaultObjectForm Then
			ObjectFormPresentation(Object);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	Else // Getting form presentation for Document, Chart of accounts, Chart of calculation types, Business process, and Task.
		
		If Form = Object.DefaultListForm
			Or Form = Object.DefaultChoiceForm Then
			FormName = ListFormPresentation(Object);
			CanOpenForm = ?(Form = Object.DefaultListForm, True, False);
		ElsIf Form = Object.DefaultObjectForm Then
			FormName = ObjectFormPresentation(Object);
		Else
			FormName = Form.Synonym;
		EndIf;
		
	EndIf;
	
	Return New Structure("FormName, CanOpenForm", FormName, CanOpenForm);
	
EndFunction

Function AutogeneratedFormPresentation(Object, Form, MetadataObjectType)
	
	CanOpenForm = False;
	
	If MetadataObjectType = "FilterCriterion"
		Or MetadataObjectType = "DocumentJournal" Then
		
		FormName = ListFormPresentation(Object);
		CanOpenForm = True;
		
	ElsIf MetadataObjectType = "AccumulationRegister"
		Or MetadataObjectType = "AccountingRegister"
		Or MetadataObjectType = "CalculationRegister" Then
		
		FormName = ListFormPresentation(Object);
		CanOpenForm = True;
		
	ElsIf MetadataObjectType = "InformationRegister" Then
		
		If Form = "RecordForm" Then
			
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
			
		ElsIf Form = "ListForm" Then
			FormName = ListFormPresentation(Object);
			CanOpenForm = True;
		EndIf;
		
	ElsIf MetadataObjectType = "Report"
		Or MetadataObjectType = "DataProcessor" Then
		
		If Not IsBlankString(Object.ExtendedPresentation) Then
			FormName = Object.ExtendedPresentation;
		Else
			FormName = Object.Presentation();
		EndIf;
		CanOpenForm = True;
		
	ElsIf MetadataObjectType = "Enum" Then
		
		FormName = ListFormPresentation(Object);
		CanOpenForm = ?(Form = "ListForm", True, False);
		
	ElsIf MetadataObjectType = "Catalog"
		Or MetadataObjectType = "ChartOfCharacteristicTypes" Then
		
		If Form = "ListForm"
			Or Form = "ChoiceForm"
			Or Form = "FolderForm"
			Or Form = "FolderChoiceForm" Then
			FormName = ListFormPresentation(Object);
			AddFormTypeToAutogeneratedFormPresentation(Object, Form, FormName);
			CanOpenForm = ?(Form = "ListForm", True, False);
		ElsIf Form = "ObjectForm" Then
			FormName = ObjectFormPresentation(Object);
		EndIf;
		
	ElsIf MetadataObjectType = "ExternalDataSource" Then
		
		If Form = "ListForm" Then
			FormName = ListFormPresentation(Object);
			CanOpenForm = True;
		ElsIf Form = "RecordForm" Then
			If Not IsBlankString(Object.ExtendedRecordPresentation) Then
				FormName = Object.ExtendedRecordPresentation ;
			ElsIf Not IsBlankString(Object.RecordPresentation) Then
				FormName = Object.RecordPresentation;
			Else
				FormName = Object.Presentation();
			EndIf;
		ElsIf Form = "ObjectForm" Then
			ObjectFormPresentation(Object);
		EndIf;
		
	Else // Getting form presentation for Document, Chart of accounts, Chart of calculation types, Business process, and Task.
		
		If Form = "ListForm"
			Or Form = "ChoiceForm" Then
			FormName = ListFormPresentation(Object);
			CanOpenForm = ?(Form = "ListForm", True, False);
		ElsIf Form = "ObjectForm" Then
			FormName = ObjectFormPresentation(Object);
		EndIf;
		
	EndIf;
	
	Return New Structure("FormName, CanOpenForm", FormName, CanOpenForm);
	
EndFunction

Function ListFormPresentation(Object)
	
	If Not IsBlankString(Object.ExtendedListPresentation) Then
		FormName = Object.ExtendedListPresentation;
	ElsIf Not IsBlankString(Object.ListPresentation) Then
		FormName = Object.ListPresentation;
	Else
		FormName = Object.Presentation();
	EndIf;
	
	Return FormName;
EndFunction

Function ObjectFormPresentation(Object)
	
	If Not IsBlankString(Object.ExtendedObjectPresentation) Then
		FormName = Object.ExtendedObjectPresentation;
	ElsIf Not IsBlankString(Object.ObjectPresentation) Then
		FormName = Object.ObjectPresentation;
	Else
		FormName = Object.Presentation();
	EndIf;;
	
	Return FormName;
EndFunction

Procedure AddFormTypeToPresentation(Object, Form, FormName)
	
	If Form = Object.DefaultListForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (список)'; en = '%1 (list)'; pl = '%1 (lista)';es_ES = '%1 (lista)';es_CO = '%1 (lista)';tr = '%1 (liste)';it = '%1 (elenco)';de = '%1 (Liste)'"), FormName);
	ElsIf Form = Object.DefaultChoiceForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (выбор)'; en = '%1 (choice)'; pl = '%1 (wybór)';es_ES = '%1 (selección)';es_CO = '%1 (selección)';tr = '%1 (seçim)';it = '%1 (scelta)';de = '%1 (Auswahl)'"), FormName);
	ElsIf Form = Object.DefaultFolderForm Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (группа)'; en = '%1 (group)'; pl = '%1 (grupa)';es_ES = '%1 (grupo)';es_CO = '%1 (grupo)';tr = '%1 (grup)';it = '%1 (gruppo)';de = '%1 (Gruppe)'"), FormName);
	EndIf;
	
EndProcedure

Procedure AddFormTypeToAutogeneratedFormPresentation(Object, Form, FormName)
	
	If Form = "ListForm" Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (список)'; en = '%1 (list)'; pl = '%1 (lista)';es_ES = '%1 (lista)';es_CO = '%1 (lista)';tr = '%1 (liste)';it = '%1 (elenco)';de = '%1 (Liste)'"), FormName);
	ElsIf Form = "ChoiceForm" Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (выбор)'; en = '%1 (choice)'; pl = '%1 (wybór)';es_ES = '%1 (selección)';es_CO = '%1 (selección)';tr = '%1 (seçim)';it = '%1 (scelta)';de = '%1 (Auswahl)'"), FormName);
	ElsIf Form = "FolderChoiceForm" Then
		FormName = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1 (группа)'; en = '%1 (group)'; pl = '%1 (grupa)';es_ES = '%1 (grupo)';es_CO = '%1 (grupo)';tr = '%1 (grup)';it = '%1 (gruppo)';de = '%1 (Gruppe)'"), FormName);
	EndIf;
	
EndProcedure

Procedure AddRowToValueTable(SettingsTable, SettingsSelection)
	
	If StrFind(SettingsSelection.ObjectKey, "ExternalReport.") <> 0 Then
		Return;
	EndIf;
	
	NewRow = SettingsTable.Add();
	NewRow.ObjectKey = SettingsSelection.ObjectKey;
	NewRow.SettingsKey = SettingsSelection.SettingsKey;
	
EndProcedure

Function ReportOptionPresentation(SettingsItemKey, ReportOptionName)
	
	NameOfReport = StrSplit(ReportOptionName[0], ".", False);
	Report = Metadata.Reports.Find(NameOfReport[1]);
	
	If Report = Undefined Then
		Return Undefined;
	EndIf;
	
	OptionsStorage = Report.VariantsStorage;
	
	If OptionsStorage = Undefined Then
		OptionsStorage = Metadata.ReportsVariantsStorage;
	EndIf;
	
	If OptionsStorage = Undefined Then
		OptionsStorage = ReportsVariantsStorage;
	Else
		OptionsStorage = SettingsStorages[OptionsStorage.Name];
	EndIf;
	
	If ReportOptionName.Count() = 1 Then
		OptionID = NameOfReport[1];
	Else
		OptionID = ReportOptionName[1];
	EndIf;
	
	ReportOptionPresentation = OptionsStorage.GetDescription(ReportOptionName[0], OptionID);
	
	If ReportOptionPresentation <> Undefined Then
		Return ReportOptionPresentation.Presentation;
	Else
		Return NameOfReport[1];
	EndIf;
	
EndFunction

Function ReadSettingsFromStorage(SettingsManager, User)
	
	Settings = New ValueTable;
	Settings.Columns.Add("ObjectKey");
	Settings.Columns.Add("SettingsKey");
	Settings.Columns.Add("Presentation");
	
	Filter = New Structure;
	Filter.Insert("User", User);
	
	Ignore = False;
	SettingsSelection = SettingsManager.Select(Filter);
	While NextSettingsItem(SettingsSelection, Ignore) Do
		
		If Ignore Then
			Continue;
		EndIf;
		
		NewRow = Settings.Add();
		NewRow.ObjectKey = SettingsSelection.ObjectKey;
		NewRow.SettingsKey = SettingsSelection.SettingsKey;
		NewRow.Presentation = SettingsSelection.Presentation;
		
	EndDo;
	
	Return Settings;
	
EndFunction

Function UserReportOptions(InfobaseUser)
	
	CurrentUser = Users.CurrentUser();
	CurrentIBUser = IBUserName(CurrentUser);
	
	ReportOptionTable = New ValueTable;
	ReportOptionTable.Columns.Add("ObjectKey");
	ReportOptionTable.Columns.Add("VariantKey");
	ReportOptionTable.Columns.Add("Presentation");
	ReportOptionTable.Columns.Add("StandardProcessing");
	
	AvailableReports = ReportsAvailableToUser(CurrentIBUser);
	
	For Each ReportMetadata In Metadata.Reports Do
		
		StandardProcessing = True;
		
		If AvailableReports.Find("Report." + ReportMetadata.Name) = Undefined Then
			Continue;
		EndIf;
		
		SSLSubsystemsIntegration.OnReceiveUserReportsOptions(ReportMetadata,
			InfobaseUser, ReportOptionTable, StandardProcessing);
		
		If StandardProcessing Then
			ReportOptions = ReportsVariantsStorage.GetList("Report." + ReportMetadata.Name, InfobaseUser);
			For Each ReportOption In ReportOptions Do
				ReportOptionRow = ReportOptionTable.Add();
				ReportOptionRow.ObjectKey = "Report." + ReportMetadata.Name;
				ReportOptionRow.VariantKey = ReportOption.Value;
				ReportOptionRow.Presentation = ReportOption.Presentation;
				ReportOptionRow.StandardProcessing = True;
			EndDo;
		EndIf;
		
	EndDo;
	
	Return ReportOptionTable;
	
EndFunction

Function UserSettingsKeys()
	
	KeyArray = New Array;
	KeyArray.Add("CurrentVariantKey");
	KeyArray.Add("CurrentUserSettingsKey");
	KeyArray.Add("CurrentUserSettings");
	KeyArray.Add("CurrentDataSettingsKey");
	KeyArray.Add("ClientSettings");
	KeyArray.Add("AddInSettings");
	KeyArray.Add("HelpSettings");
	KeyArray.Add("ComparisonSettings");
	KeyArray.Add("TableSearchParameters");
	
	Return KeyArray;
EndFunction

Function SettingsStorageByName(StorageDescription)
	
	If StorageDescription = "ReportsUserSettingsStorage" Then
		Return ReportsUserSettingsStorage;
	ElsIf StorageDescription = "CommonSettingsStorage" Then
		Return CommonSettingsStorage;
	Else
		Return SystemSettingsStorage;
	EndIf;
	
EndFunction

Procedure GenerateFilter(UserGroupList, GroupRef, GroupsArray)
	
	FilterParameters = New Structure("Parent", GroupRef);
	PickedRows = UserGroupList.FindRows(FilterParameters);
	
	For Each Item In PickedRows Do 
		GroupsArray.Add(Item);
	EndDo;
	
EndProcedure

Function GetReportOptionKeys(ReportOptionTable)
	
	ReportOptionKeyAndTypeTable = New ValueTable;
	ReportOptionKeyAndTypeTable.Columns.Add("VariantKey");
	ReportOptionKeyAndTypeTable.Columns.Add("Check");
	For Each TableRow In ReportOptionTable Do
		ValueTableRow = ReportOptionKeyAndTypeTable.Add();
		ValueTableRow.VariantKey = TableRow.ObjectKey + "/" + TableRow.VariantKey;
		ValueTableRow.Check = TableRow.StandardProcessing;
	EndDo;
	
	Return ReportOptionKeyAndTypeTable;
EndFunction

Function CreateReportOnCopyingSettings(NotCopiedReportSettings,
										UserReportOptionTable = Undefined) Export
	
	SpreadsheetDoc = New SpreadsheetDocument;
	TabTemplate = GetTemplate("ReportTemplate");
	
	ReportIsNotEmpty = False;
	If UserReportOptionTable <> Undefined
		AND UserReportOptionTable.Count() <> 0 Then
		AreaHeader = TabTemplate.GetArea("Title");
		AreaHeader.Parameters.Details = 
			NStr("ru = 'Невозможно скопировать личные варианты отчетов.
			|Для того чтобы личный вариант отчета стал доступен другим пользователям,
			|необходимо его пересохранить со снятой пометкой ""Только для автора"".
			|Список пропущенных вариантов отчетов:'; 
			|en = 'Cannot copy personal report options.
			|To make a personal report option available to other users, save it with the ""Available to author only"" check box cleared.
			|
			|Skipped report options:'; 
			|pl = 'Kopiowanie osobistych wersji raportów nie jest możliwe. 
			|Aby udostępnić osobistą wersję raportu innym użytkownikom,
			|konieczne jest ponowne zapisanie go z usuniętym znakiem ""Tylko dla autora"".
			|Lista pominiętych opcji raportów:';
			|es_ES = 'Es imposible copiar las opciones personales de los informes.
			|Si quiere que la opción de informe personal esté disponible para otros usuarios,
			| entonces usted necesita volver a guardarla con la marca ""Solo para el autor"" eliminada.
			|Lista de las opciones de informes saltados:';
			|es_CO = 'Es imposible copiar las opciones personales de los informes.
			|Si quiere que la opción de informe personal esté disponible para otros usuarios,
			| entonces usted necesita volver a guardarla con la marca ""Solo para el autor"" eliminada.
			|Lista de las opciones de informes saltados:';
			|tr = '
			|Kişisel rapor seçeneklerinin kopyalanması mümkün değildir. 
			|Kişisel rapor seçeneğini diğer kullanıcılara sunmak istiyorsanız, 
			|""Yalnızca sahibi için"" işaretini kaldırmanız gerekir. Atlanan rapor seçeneklerinin listesi:';
			|it = 'È impossibile copiare le versioni personali dei report.
			|Per poter rendere disponibile una versione di un report personale ad altri utenti,
			|è necessario salvarlo nuovamente con il contrassegno ""Solo per autore"" rimosso.
			|L''elenco delle versioni di report omesse:';
			|de = 'Es ist nicht möglich, persönliche Berichtsvarianten zu kopieren.
			|Um die persönliche Berichtsvariante anderen Benutzern zur Verfügung zu stellen,
			|sollten Sie sie mit dem Kennzeichen ""Nur Autor"" neu speichern.
			|Die Liste der verpassten Berichtsvarianten:'");
		SpreadsheetDoc.Put(AreaHeader);
		
		SpreadsheetDoc.Put(TabTemplate.GetArea("BlankRow"));
		
		AreaContent = TabTemplate.GetArea("ReportContent");
		
		For Each TableRow In UserReportOptionTable Do
			
			If Not TableRow.StandardProcessing Then
				AreaContent.Parameters.Name = TableRow.Presentation;
				SpreadsheetDoc.Put(AreaContent);
			EndIf;
			
		EndDo;
		
		ReportIsNotEmpty = True;
	EndIf;
	
	If NotCopiedReportSettings.Count() <> 0 Then
		AreaHeader = TabTemplate.GetArea("Title");
		AreaHeader.Parameters.Details = 
			NStr("ru = 'У следующих пользователей недостаточно прав на отчеты:'; en = 'The following users have insufficient access rights for reports:'; pl = 'Następujący użytkownicy nie mają wystarczających uprawnień do raportów:';es_ES = 'Los siguientes usuarios tienen insuficientes derechos para los informes:';es_CO = 'Los siguientes usuarios tienen insuficientes derechos para los informes:';tr = 'Aşağıdaki kullanıcılar raporlar için yetersiz haklara sahiptir:';it = 'I seguenti utenti non hanno diritti sufficienti per i report:';de = 'Folgende Benutzer haben keine ausreichenden Rechte für die Berichte:'");
		SpreadsheetDoc.Put(AreaHeader);
		
		AreaContent = TabTemplate.GetArea("ReportContent");
		
		For Each TableRow In NotCopiedReportSettings Do
			SpreadsheetDoc.Put(TabTemplate.GetArea("BlankRow"));
			AreaContent.Parameters.Name = TableRow.User + ":";
			SpreadsheetDoc.Put(AreaContent);
			For Each ReportDescription In TableRow.ReportsList Do
				AreaContent.Parameters.Name = ReportDescription.Value;
				SpreadsheetDoc.Put(AreaContent);
			EndDo;
			
		EndDo;
		
	ReportIsNotEmpty = True;
	EndIf;
	
	If ReportIsNotEmpty Then
		Report = New SpreadsheetDocument;
		Report.Put(SpreadsheetDoc);
		
		Return Report;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function SkipSettingsItem(ObjectKey, SettingsKey)
	
	ExceptionsByObjectKey = New Array;
	ExceptionsBySettingsKey = New Array;
	
	// Exceptions. Settings that cannot be copied.
	ExceptionsByObjectKey.Add("LocalFileCache");
	ExceptionsBySettingsKey.Add("PathToLocalFileCache");
	
	If ExceptionsByObjectKey.Find(ObjectKey) <> Undefined
		AND ExceptionsBySettingsKey.Find(SettingsKey) <> Undefined Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions for AppUserSettings and SelectSettings forms.

Procedure FillSettingsLists(Parameters) Export
	FillReportSettingsList(Parameters);
	FillInterfaceSettingsList(Parameters);
	FillOtherSettingsList(Parameters);
EndProcedure

Procedure FillReportSettingsList(Parameters)
	
	FormName = StrSplit(Parameters.FormName, ".", False);
	Parameters.ReportSettingsTree.Rows.Clear();
	ReportOptionTable = UserReportOptions(Parameters.InfoBaseUser);
	Parameters.UserReportOptions.Clear();
	Parameters.UserReportOptions = ReportOptionTable.Copy();
	
	Settings = ReadSettingsFromStorage(
		ReportsUserSettingsStorage, Parameters.InfoBaseUser);
	
	CurrentObject = Undefined;
	
	For Each Setting In Settings Do
		SettingObject = Setting.ObjectKey;
		SettingsItemKey = Setting.SettingsKey;
		SettingName = Setting.Presentation;
		
		ReportOptionName = StrSplit(SettingObject, "/", False);
		If ReportOptionName.Count() < 2 Then
			Continue; // Incorrect setting.
		EndIf;
		
		ReportOptionPresentation = ReportOptionPresentation(SettingsItemKey, ReportOptionName);
		
		// If a report option (report) has been deleted, but the setting remains, it is not displayed to the user.
		If ReportOptionPresentation = ""
			Or ReportOptionPresentation = Undefined Then
			Continue;
		EndIf;
		
		// Checking whether the report option is a user-defined one.
		FoundReportOption = ReportOptionTable.Find(ReportOptionName[1], "VariantKey");
		// If the settings selection form is opened, hide the settings that cannot be copied
		If FormName[3] = "SettingsChoice"
			AND FoundReportOption <> Undefined
			AND Not FoundReportOption.StandardProcessing Then
			Continue;
		EndIf;
		
		If Not IsBlankString(Parameters.Search) Then
			If StrFind(Upper(ReportOptionPresentation), Upper(Parameters.Search)) = 0
				AND StrFind(Upper(SettingName), Upper(Parameters.Search)) = 0 Then
				Continue;
			EndIf;
		EndIf;
		
		// Filling a report option row.
		If CurrentObject <> ReportOptionPresentation Then
			NewRowReportOption = Parameters.ReportSettingsTree.Rows.Add();
			NewRowReportOption.Settings = ReportOptionPresentation;
			NewRowReportOption.Picture = PictureLib.Report;
			NewRowReportOption.Type =
				?(FoundReportOption <> Undefined, 
					?(Not FoundReportOption.StandardProcessing, "PersonalOption", "StandardOptionPersonal"), "StandardReportOption");
			NewRowReportOption.RowType = "Report" + ReportOptionPresentation;
		EndIf;
		// Filling a setting string
		NewRowSettingsItem = NewRowReportOption.Rows.Add();
		NewRowSettingsItem.Settings = ?(Not IsBlankString(SettingName), SettingName, ReportOptionPresentation);
		NewRowSettingsItem.Picture = PictureLib.Form;
		NewRowSettingsItem.Type = 
			?(FoundReportOption <> Undefined,
				?(Not FoundReportOption.StandardProcessing, "SettingsItemPersonal", "StandardSettingsItemPersonal"), "StandardReportSettings");
		NewRowSettingsItem.RowType = ReportOptionPresentation + SettingName;
		NewRowSettingsItem.Keys.Add(SettingObject, SettingsItemKey);
		// Filling object key and settings item key for a report option.
		NewRowReportOption.Keys.Add(SettingObject, SettingsItemKey);
		
		CurrentObject = ReportOptionPresentation;
		
		// Deleting reports that have settings from the list of user-defined report options.
		If FoundReportOption <> Undefined Then
			ReportOptionTable.Delete(FoundReportOption);
		EndIf;
		
	EndDo;
	
	For Each ReportOption In ReportOptionTable Do
		
		If FormName[3] = "SettingsChoice"
			AND Parameters.SettingsOperation = "Copy"
			AND Not ReportOption.StandardProcessing Then
			Continue;
		EndIf;
		
		If Not IsBlankString(Parameters.Search) Then
			
			If StrFind(Upper(ReportOption.Presentation), Upper(Parameters.Search)) = 0 Then
				Continue;
			EndIf;
			
		EndIf;
		
		NewRowReportOption = Parameters.ReportSettingsTree.Rows.Add();
		NewRowReportOption.Settings = ReportOption.Presentation;
		NewRowReportOption.Picture = PictureLib.Report;
		NewRowReportOption.Keys.Add(ReportOption.ObjectKey + "/" + ReportOption.VariantKey);
		NewRowReportOption.Type = ?(Not ReportOption.StandardProcessing, "PersonalOption", "StandardOptionPersonal");
		NewRowReportOption.RowType = "Report" + ReportOption.Presentation;
		
	EndDo;
	
	Parameters.ReportSettingsTree.Rows.Sort("Settings Asc", True);
	
EndProcedure

Procedure FillInterfaceSettingsList(Parameters)
	
	Parameters.InterfaceSettings.Rows.Clear();
	
	CurrentObject = Undefined;
	FormSettings = AllFormSettings(Parameters.InfoBaseUser);
	
	For Each FormSettingsItem In FormSettings Do
		MetadataObjectName = StrSplit(FormSettingsItem.Value, ".", False);
		MetadataObjectPresentation = StrSplit(FormSettingsItem.Presentation, ".", False);
		
		If Not IsBlankString(Parameters.Search) Then
			
			If StrFind(Upper(FormSettingsItem.Presentation), Upper(Parameters.Search)) = 0 Then
				Continue;
			EndIf;
			
		EndIf;

		If MetadataObjectName[0] = "CommonForm" Then
			NewRowCommonForm = Parameters.InterfaceSettings.Rows.Add();
			NewRowCommonForm.Settings = FormSettingsItem.Presentation;
			NewRowCommonForm.Picture = PictureLib.Form;
			MergeValueLists(NewRowCommonForm.Keys, FormSettingsItem.KeysList);
			NewRowCommonForm.Type = "InterfaceSettings";
			NewRowCommonForm.RowType = "CommonForm" + MetadataObjectName[1];
		ElsIf MetadataObjectName[0] = "SettingsStorage" Then
			NewRowSettingsStorage = Parameters.InterfaceSettings.Rows.Add();
			NewRowSettingsStorage.Settings = FormSettingsItem.Presentation;
			NewRowSettingsStorage.Picture = PictureLib.Form;
			MergeValueLists(NewRowSettingsStorage.Keys, FormSettingsItem.KeysList);
			NewRowSettingsStorage.RowType = "SettingsStorage" + MetadataObjectName[2];
			NewRowSettingsStorage.Type = "InterfaceSettings";
		ElsIf MetadataObjectPresentation[0] = NStr("ru = 'Стандартные'; en = 'Standard'; pl = 'Standardowy';es_ES = 'Estándar';es_CO = 'Estándar';tr = 'Standart';it = 'Standard';de = 'Standard'") Then
			
			// Settings tree group
			If CurrentObject <> MetadataObjectPresentation[0] Then
				NewRowMetadataObject = Parameters.InterfaceSettings.Rows.Add();
				NewRowMetadataObject.Settings = MetadataObjectPresentation[0];
				NewRowMetadataObject.Picture = FormSettingsItem.Picture;
				NewRowMetadataObject.RowType = "Object" + MetadataObjectName[1];
				NewRowMetadataObject.Type = "InterfaceSettings";
			EndIf;
			
			// Settings tree item
			NewFormInterfaceRow = NewRowMetadataObject.Rows.Add();
			NewFormInterfaceRow.Settings = MetadataObjectPresentation[1];
			NewFormInterfaceRow.Picture = PictureLib.Form;
			NewFormInterfaceRow.RowType = MetadataObjectName[1] + MetadataObjectName[2];
			NewFormInterfaceRow.Type = "InterfaceSettings";
			MergeValueLists(NewFormInterfaceRow.Keys, FormSettingsItem.KeysList);
			MergeValueLists(NewRowMetadataObject.Keys, FormSettingsItem.KeysList);
			
			CurrentObject = MetadataObjectPresentation[0];
			
		Else
			
			// Settings tree group
			If CurrentObject <> MetadataObjectName[1] Then
				NewRowMetadataObject = Parameters.InterfaceSettings.Rows.Add();
				NewRowMetadataObject.Settings = MetadataObjectPresentation[0];
				NewRowMetadataObject.Picture = FormSettingsItem.Picture;
				NewRowMetadataObject.RowType = "Object" + MetadataObjectName[1];
				NewRowMetadataObject.Type = "InterfaceSettings";
			EndIf;
			
			// Settings tree item
			If MetadataObjectName.Count() = 3 Then
				FormName = MetadataObjectName[2];
			Else
				FormName = MetadataObjectName[3];
			EndIf;
			
			NewFormInterfaceRow = NewRowMetadataObject.Rows.Add();
			If MetadataObjectPresentation.Count() = 1 Then
				NewFormInterfaceRow.Settings = MetadataObjectPresentation[0];
			Else
				NewFormInterfaceRow.Settings = MetadataObjectPresentation[1];
			EndIf;
			NewFormInterfaceRow.Picture = PictureLib.Form;
			NewFormInterfaceRow.RowType = MetadataObjectName[1] + FormName;
			NewFormInterfaceRow.Type = "InterfaceSettings";
			MergeValueLists(NewFormInterfaceRow.Keys, FormSettingsItem.KeysList);
			MergeValueLists(NewRowMetadataObject.Keys, FormSettingsItem.KeysList);
			
			CurrentObject = MetadataObjectName[1];
		EndIf;
		
	EndDo;
	
	AddDesktopAndCommandInterfaceSettings(Parameters, Parameters.InterfaceSettings);
	
	Parameters.InterfaceSettings.Rows.Sort("Settings Asc", True);
	
	Setting = NStr("ru = 'Командный интерфейс и начальная страница'; en = 'Command interface and home page'; pl = 'Interfejs poleceń i strona początkowa';es_ES = 'Interfaz de comando y página principal';es_CO = 'Interfaz de comando y página principal';tr = 'Komut arayüzü ve ana sayfa';it = 'Interfaccia di comando e home page';de = 'Befehlsoberfläche und Startseite'");
	DesktopAndCommandInterface = Parameters.InterfaceSettings.Rows.Find(Setting, "Settings");
	
	If DesktopAndCommandInterface <> Undefined Then
		RowIndex = Parameters.InterfaceSettings.Rows.IndexOf(DesktopAndCommandInterface);
		Parameters.InterfaceSettings.Rows.Move(RowIndex, -RowIndex);
	EndIf;
	
	
	
EndProcedure

Procedure FillOtherSettingsList(Parameters)
	
	Parameters.OtherSettingsTree.Rows.Clear();
	Settings = ReadSettingsFromStorage(CommonSettingsStorage, Parameters.InfoBaseUser);
	Keys = New ValueList;
	OtherKeys = New ValueList;
	
	// Filling personal settings.
	For Each Setting In Settings Do
		Keys.Add(Setting.ObjectKey, Setting.SettingsKey);
	EndDo;
	
	OutputSettingsItem = True;
	If Keys.Count() > 0 Then
		
		If Not IsBlankString(Parameters.Search) Then
			If StrFind(Upper(NStr("ru = 'Персональные настройки'; en = 'Personal settings'; pl = 'Personalne ustawienia';es_ES = 'Configuraciones personales';es_CO = 'Configuraciones personales';tr = 'Kişisel ayarlar';it = 'Impostazioni personalizzate';de = 'Persönliche Einstellungen'")), Upper(Parameters.Search)) = 0 Then
				OutputSettingsItem = False;
			EndIf;
		EndIf;
		
		If OutputSettingsItem Then
			Setting = NStr("ru = 'Персональные настройки'; en = 'Personal settings'; pl = 'Personalne ustawienia';es_ES = 'Configuraciones personales';es_CO = 'Configuraciones personales';tr = 'Kişisel ayarlar';it = 'Impostazioni personalizzate';de = 'Persönliche Einstellungen'");
			SettingType = "PersonalSettings";
			Picture = PictureLib.UserState02;
			AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, Keys, SettingType);
		EndIf;
		
	EndIf;
	
	// Filling print settings and favorites settings.
	Settings = ReadSettingsFromStorage(SystemSettingsStorage, Parameters.InfoBaseUser);
	
	Keys.Clear();
	HasFavorites = False;
	HasPrintSettings = False;
	KeyEnds = UserSettingsKeys();
	For Each Setting In Settings Do
		
		SettingName = StrSplit(Setting.ObjectKey, "/", False);
		If SettingName.Count() = 1 Then
			Continue;
		EndIf;
		
		If KeyEnds.Find(SettingName[1]) <> Undefined Then
			OtherKeys.Add(Setting.ObjectKey, "OtherItems");
		EndIf;
		
		If SettingName[1] = "UserWorkFavorites" Then
			HasFavorites = True;
		ElsIf SettingName[1] = "SpreadsheetDocumentPrintSettings" Then
			Keys.Add(Setting.ObjectKey, "OtherItems");
			HasPrintSettings = True;
		EndIf;
		
	EndDo;
	
	// Adding print settings tree row.
	OutputSettingsItem = True;
	If Not IsBlankString(Parameters.Search) Then
		
		If StrFind(Upper(NStr("ru = 'Настройки печати табличных документов'; en = 'Spreadsheet document print settings'; pl = 'Ustawienia drukowania dokumentu arkuszy kalkulacyjnych';es_ES = 'Configuraciones de la impresión de los documentos de la hoja de cálculo';es_CO = 'Configuraciones de la impresión de los documentos de la hoja de cálculo';tr = 'E-tablo belgesi yazdırma ayarları';it = 'Impostazioni di stampa foglio elettronico';de = 'Druckeinstellungen für das Tabellenblatt'")), Upper(Parameters.Search)) = 0 Then
			OutputSettingsItem = False;
		EndIf;
		
	EndIf;
	
	If HasPrintSettings
		AND OutputSettingsItem Then
		Setting = NStr("ru = 'Настройки печати табличных документов'; en = 'Spreadsheet document print settings'; pl = 'Ustawienia drukowania dokumentu arkuszy kalkulacyjnych';es_ES = 'Configuraciones de la impresión de los documentos de la hoja de cálculo';es_CO = 'Configuraciones de la impresión de los documentos de la hoja de cálculo';tr = 'E-tablo belgesi yazdırma ayarları';it = 'Impostazioni di stampa foglio elettronico';de = 'Druckeinstellungen für das Tabellenblatt'");
		Picture = PictureLib.Print;
		SettingType = "PrintSettings";
		AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, Keys, SettingType);
	EndIf;
	
	// Adding "Favorites" tree row.
	OutputSettingsItem = True;
	If Not IsBlankString(Parameters.Search) Then
		
		If StrFind(Upper(NStr("ru = 'Избранное'; en = 'Favorites'; pl = 'Ulubione';es_ES = 'Favoritos';es_CO = 'Favoritos';tr = 'Sık kullanılanlar';it = 'Preferiti';de = 'Favoriten'")), Upper(Parameters.Search)) = 0 Then
			OutputSettingsItem = False;
		EndIf;
		
	EndIf;
	
	If HasFavorites
		AND OutputSettingsItem Then
		
		Setting = NStr("ru = 'Избранное'; en = 'Favorites'; pl = 'Ulubione';es_ES = 'Favoritos';es_CO = 'Favoritos';tr = 'Sık kullanılanlar';it = 'Preferiti';de = 'Favoriten'");
		Picture = PictureLib.AddToFavorites;
		Keys.Clear();
		Keys.Add("Common/UserWorkFavorites", "OtherItems");
		SettingType = "FavoritesSettings";
		AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, Keys, SettingType);
		
	EndIf;
	
	// Adding other settings supported by the configuration.
	OtherSettings = New Structure;
	UserInfo = New Structure;
	UserInfo.Insert("UserRef", Parameters.UserRef);
	UserInfo.Insert("InfobaseUserName", Parameters.InfoBaseUser);
	
	UsersInternal.OnGetOtherUserSettings(UserInfo, OtherSettings);
	Keys = New ValueList;
	
	If OtherSettings <> Undefined Then
		
		For Each OtherSetting In OtherSettings Do
			
			Result = OtherSetting.Value;
			If Result.SettingsList.Count() <> 0 Then
				
				OutputSettingsItem = True;
				If Not IsBlankString(Parameters.Search) Then
					
					If StrFind(Upper(Result.SettingName), Upper(Parameters.Search)) = 0 Then
						OutputSettingsItem = False;
					EndIf;
					
				EndIf;
				
				If OutputSettingsItem Then
					
					If OtherSetting.Key = "QuickAccessSetting" Then
						For Each Item In Result.SettingsList Do
							SettingValue = Item[0];
							SettingID = Item[1];
							Keys.Add(SettingValue, SettingID);
						EndDo;
					Else
						Keys = Result.SettingsList.Copy();
					EndIf;
					
					Setting = Result.SettingName;
					If Result.PictureSettings = "" Then
						Picture = PictureLib.OtherUserSettings;
					Else
						Picture = Result.PictureSettings;
					EndIf;
					Type = "OtherUserSettingsItem";
					SettingType = OtherSetting.Key;
					AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, Keys, Type, SettingType);
					Keys.Clear();
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Other settings that are not included in other sections.
	OutputSettingsItem = True;
	If Not IsBlankString(Parameters.Search) Then
		
		If StrFind(Upper(NStr("ru = 'Прочие настройки'; en = 'Other settings'; pl = 'Inne ustawienia';es_ES = 'Otras configuraciones';es_CO = 'Otras configuraciones';tr = 'Diğer ayarlar';it = 'Altre impostazioni';de = 'Andere Einstellungen'")), Upper(Parameters.Search)) = 0 Then
			OutputSettingsItem = False;
		EndIf;
		
	EndIf;
	
	If OtherKeys.Count() <> 0
		AND OutputSettingsItem Then
		Setting = NStr("ru = 'Прочие настройки'; en = 'Other settings'; pl = 'Inne ustawienia';es_ES = 'Otras configuraciones';es_CO = 'Otras configuraciones';tr = 'Diğer ayarlar';it = 'Altre impostazioni';de = 'Andere Einstellungen'");
		Picture = PictureLib.OtherUserSettings;
		SettingType = "OtherSetting";
		AddTreeRow(Parameters.OtherSettingsTree, Setting, Picture, OtherKeys, SettingType);
	EndIf;
	
EndProcedure

Procedure AddDesktopAndCommandInterfaceSettings(Parameters, SettingsTree)
	
	If Not IsBlankString(Parameters.Search) Then
		If StrFind(Upper(NStr("ru = 'Командный интерфейс и начальная страница'; en = 'Command interface and home page'; pl = 'Interfejs poleceń i strona początkowa';es_ES = 'Interfaz de comando y página principal';es_CO = 'Interfaz de comando y página principal';tr = 'Komut arayüzü ve ana sayfa';it = 'Interfaccia di comando e home page';de = 'Befehlsoberfläche und Startseite'")), Upper(Parameters.Search)) = 0 Then
			Return;
		EndIf;
	EndIf;
	
	Settings = ReadSettingsFromStorage(SystemSettingsStorage, Parameters.InfoBaseUser);
	DesktopSettingsKeys = New ValueList;
	InterfaceSettingsKeys = New ValueList;
	AllSettingsKeys = New ValueList; 
	
	For Each Setting In Settings Do
		SettingName = StrSplit(Setting.ObjectKey, "/", False);
		SettingsItemNamePart = StrSplit(SettingName[0], ".", False);
		If SettingsItemNamePart[0] = "Subsystem" Then
			
			InterfaceSettingsKeys.Add(Setting.ObjectKey, "Interface");
			AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			
		ElsIf SettingName[0] = "Common" Then
			
			If SettingName[1] = "SectionsPanel"
			 Or SettingName[1] = "ActionsPanel" 
			 Or SettingName[1] = "ClientSettings" 
			 Or SettingName[1] = "ClientApplicationInterfaceSettings" Then
				
				InterfaceSettingsKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
				
			ElsIf SettingName[1] = "DesktopSettings"
			      Or SettingName[1] = "HomePageSettings" Then
				
				DesktopSettingsKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			EndIf;
			
		ElsIf SettingName[0] = "Desktop" Then
			
			If SettingName[1] = "WindowSettings" Then
				DesktopSettingsKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			Else
				InterfaceSettingsKeys.Add(Setting.ObjectKey, "Interface");
				AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			EndIf;
			
		ElsIf SettingName[0] = "HomePage" Then
			
			// Window settings.
			DesktopSettingsKeys.Add(Setting.ObjectKey, "Interface");
			AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			
		ElsIf SettingName[0] = "MainSection" Then
			
			InterfaceSettingsKeys.Add(Setting.ObjectKey, "Interface");
			AllSettingsKeys.Add(Setting.ObjectKey, "Interface");
			
		EndIf;
		
	EndDo;
	
	If AllSettingsKeys.Count() > 0 Then
		// Adding top-level groups for desktop settings and command-interface settings.
		NewInterfaceRow = SettingsTree.Rows.Add();
		NewInterfaceRow.Settings = NStr("ru = 'Командный интерфейс и начальная страница'; en = 'Command interface and home page'; pl = 'Interfejs poleceń i strona początkowa';es_ES = 'Interfaz de comando y página principal';es_CO = 'Interfaz de comando y página principal';tr = 'Komut arayüzü ve ana sayfa';it = 'Interfaccia di comando e home page';de = 'Befehlsoberfläche und Startseite'");
		NewInterfaceRow.Picture = PictureLib.Picture;
		NewInterfaceRow.RowType = NStr("ru = 'Командный интерфейс и начальная страница'; en = 'Command interface and home page'; pl = 'Interfejs poleceń i strona początkowa';es_ES = 'Interfaz de comando y página principal';es_CO = 'Interfaz de comando y página principal';tr = 'Komut arayüzü ve ana sayfa';it = 'Interfaccia di comando e home page';de = 'Befehlsoberfläche und Startseite'");
		NewInterfaceRow.Type = "InterfaceSettings";
		NewInterfaceRow.Keys = AllSettingsKeys.Copy();
	EndIf;
	
	If DesktopSettingsKeys.Count() > 0 Then
		// Creating a desktop settings row.
		NewSubordinateInterfaceRow = NewInterfaceRow.Rows.Add();
		NewSubordinateInterfaceRow.Settings = NStr("ru = 'Начальная страница'; en = 'Home page'; pl = 'Strona początkowa';es_ES = 'Página principal';es_CO = 'Página principal';tr = 'Ana sayfa';it = 'Pagina iniziale';de = 'Startseite'");
		NewSubordinateInterfaceRow.Picture = PictureLib.Picture;
		NewSubordinateInterfaceRow.RowType = "DesktopSettings";
		NewSubordinateInterfaceRow.Type = "InterfaceSettings";
		NewSubordinateInterfaceRow.Keys = DesktopSettingsKeys.Copy();
	EndIf;
	
	If InterfaceSettingsKeys.Count() > 0 Then
		// Creating a command interface settings row.
		NewSubordinateInterfaceRow = NewInterfaceRow.Rows.Add();
		NewSubordinateInterfaceRow.Settings = NStr("ru = 'Командный интерфейс'; en = 'Command interface'; pl = 'Interfejs poleceń';es_ES = 'Interfaz de comandos';es_CO = 'Interfaz de comandos';tr = 'Komut arayüzü';it = 'Interfaccia di comando';de = 'Befehlsschnittstelle'");
		NewSubordinateInterfaceRow.Picture = PictureLib.Picture;
		NewSubordinateInterfaceRow.RowType = "CommandInterfaceSettings";
		NewSubordinateInterfaceRow.Type = "InterfaceSettings";
		NewSubordinateInterfaceRow.Keys = InterfaceSettingsKeys.Copy();
	EndIf;
	
EndProcedure

Procedure MergeValueLists(DestinationList, SourceList)
	For Each Item In SourceList Do
		FillPropertyValues(DestinationList.Add(), Item);
	EndDo;
EndProcedure

Procedure AddTreeRow(ValuesTree, Setting, Picture, Keys, Type = "", RowType = "")
	
	NewRow = ValuesTree.Rows.Add();
	NewRow.Settings = Setting;
	NewRow.Picture = Picture;
	NewRow.Type = Type;
	NewRow.RowType = ?(RowType <> "", RowType, Type);
	NewRow.Keys = Keys.Copy();
	
EndProcedure

#EndRegion

#EndIf