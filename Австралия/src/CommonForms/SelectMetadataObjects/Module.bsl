////////////////////////////////////////////////////////////////////////////////
//                          HOW TO USE THE FORM                               //
//
// The form is intended for selecting configuration metadata objects and passing them to a calling 
// environment.
//
// Call parameters:
// MetadataObjectsToSelectCollection - ValueList -  the available metadata object type filters.
//				
//				Example:
//					FilterByReferenceMetadata = New ValueList;
//					FilterByReferenceMetadata.Add("Catalogs");
//					FilterByReferenceMetadata.Add("Documents");
//				In this example the form allows to select only Catalogs and Documents metadata objects.
// SelectedMetadataObjects - ValueList - metadata objects that are already selected.
//				In metadata tree this objects will be marked by flags.
//				It can be useful for setting up default selected metadata objects or for changing the list of 
//				selected ones.
// ParentSubsystems - ValueList - only child subsystems of this subsystems will be displayed on the 
// 				form (for SL Embedding Wizard).
// SubsystemsWithCIOnly - Boolean - the flag that shows whether there will be only included in the 
//				command interface subsystems in the list (for SL Embedding Wizard).
// SelectSingle - Boolean - indicates whether a single metadata object is selected.
//              In this case multiselect is not allowed, furthermore, double-clicking a row with 
//              object makes selection.
// ChoiceInitialValue - String - full name of metadata where the list will be positioned during the 
//              form opening.
//

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SelectedMetadataObjects.LoadValues(Parameters.SelectedMetadataObjects.UnloadValues());
	
	If Parameters.FilterByMetadataObjects.Count() > 0 Then
		Parameters.MetadataObjectsToSelectCollection.Clear();
		For Each MetadataObjectFullName In Parameters.FilterByMetadataObjects Do
			BaseTypeName = Common.BaseTypeNameByMetadataObject(Metadata.FindByFullName(MetadataObjectFullName.Value));
			If Parameters.MetadataObjectsToSelectCollection.FindByValue(BaseTypeName) = Undefined Then
				Parameters.MetadataObjectsToSelectCollection.Add(BaseTypeName);
			EndIf;
		EndDo;
	EndIf;
	
	If Parameters.Property("SubsystemsWithCIOnly") AND Parameters.SubsystemsWithCIOnly Then
		SubsystemList = Metadata.Subsystems;
		FillSubsystemList(SubsystemList);
		SubsystemsWithCIOnly = True;
	EndIf;
	
	If Parameters.Property("SelectSingle", SelectSingle) AND SelectSingle Then
		Items.Check.Visible = False;
	EndIf;
	
	If Parameters.Property("Title") Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	
	Parameters.Property("ChoiceInitialValue", ChoiceInitialValue);
	If Not ValueIsFilled(ChoiceInitialValue)
		AND SelectSingle
		AND Parameters.SelectedMetadataObjects.Count() = 1 Then
		ChoiceInitialValue = Parameters.SelectedMetadataObjects[0].Value;
	EndIf;
	
	MetadataObjectTreeFill();
	
	If Parameters.ParentSubsystems.Count()> 0 Then
		Items.MetadataObjectsTree.InitialTreeView = InitialTreeView.ExpandAllLevels;
	EndIf;
	
	SetInitialCollectionMark(MetadataObjectsTree);
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// Settings the initial selection value.
	If CurrentLineIDOnOpen > 0 Then
		
		Items.MetadataObjectsTree.CurrentRow = CurrentLineIDOnOpen;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Form tree "Mark" field click event handler procedure.
&AtClient
Procedure CheckOnChange(Item)

	CurrentData = CurrentItem.CurrentData;
	If CurrentData.Check = 2 Then
		CurrentData.Check = 0;
	EndIf;
	SetNestedItemMarks(CurrentData);
	MarkParentItems(CurrentData);

EndProcedure

#EndRegion

#Region MetadataObjectTreeFormTableItemsEventHandlers

&AtClient
Procedure MetadataObjectsTreeChoice(Item, RowSelected, Field, StandardProcessing)

	If SelectSingle Then
		
		SelectExecute();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectExecute()
	
	If SelectSingle Then
		
		curData = Items.MetadataObjectsTree.CurrentData;
		If curData <> Undefined
			AND curData.IsMetadataObject Then
			
			SelectedMetadataObjects.Clear();
			SelectedMetadataObjects.Add(curData.FullName, curData.Presentation);
			
		Else
			
			Return;
			
		EndIf;
	Else
		
		SelectedMetadataObjects.Clear();
		
		GetData();
		
	EndIf;
	If ThisObject.OnCloseNotifyDescription = Undefined Then
		Notify("SelectMetadataObjects", SelectedMetadataObjects, Parameters.UUIDSource);
	EndIf;
	Close(SelectedMetadataObjects);
	
EndProcedure

&AtClient
Procedure CloseExecute()
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillSubsystemList(SubsystemList) 
	For Each Subsystem In SubsystemList Do
		If Subsystem.IncludeInCommandInterface Then
			ItemsOfSubsystemsWithCommandInterface.Add(Subsystem.FullName());
		EndIf;	
		
		If Subsystem.Subsystems.Count() > 0 Then
			FillSubsystemList(Subsystem.Subsystems);
		EndIf;
	EndDo;
EndProcedure

// Fill the tree of configuration object values.
// If the Parameters.MetadataObjectToSelectCollection value list is not empty, the tree is limited 
// by the passed metadata object collection list.
//  If metadata objects from the tree are found in the
// "Parameters.SelectedMetadataObjects" value list, they are marked as selected.
//
&AtServer
Procedure MetadataObjectTreeFill()
	
	MetadataObjectsCollections = New ValueTable;
	MetadataObjectsCollections.Columns.Add("Name");
	MetadataObjectsCollections.Columns.Add("Synonym");
	MetadataObjectsCollections.Columns.Add("Picture");
	MetadataObjectsCollections.Columns.Add("ObjectPicture");
	MetadataObjectsCollections.Columns.Add("IsCommonCollection");
	MetadataObjectsCollections.Columns.Add("FullName");
	MetadataObjectsCollections.Columns.Add("Parent");
	
	MetadataObjectCollections_NewRow("Subsystems",                   NStr("ru = 'Подсистемы'; en = 'Subsystems'; pl = 'Podsystemy';es_ES = 'Subsistemas';es_CO = 'Subsistemas';tr = 'Alt sistemler';it = 'Sottosistemi';de = 'Untersysteme'"),                     35, 36, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("CommonModules",                  NStr("ru = 'Общие модули'; en = 'Common modules'; pl = 'Wspólne moduły';es_ES = 'Módulos comunes';es_CO = 'Módulos comunes';tr = 'Ortak modüller';it = 'Moduli comuni';de = 'Allgemeine Module'"),                   37, 38, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("SessionParameters",              NStr("ru = 'Параметры сеанса'; en = 'Session parameters'; pl = 'Parametry sesji';es_ES = 'Parámetros de la sesión';es_CO = 'Parámetros de la sesión';tr = 'Oturum parametreleri';it = 'Parametri della sessione';de = 'Sitzungsparameter'"),               39, 40, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("Roles",                         NStr("ru = 'Роли'; en = 'Roles'; pl = 'Role';es_ES = 'Papeles';es_CO = 'Papeles';tr = 'Roller';it = 'Ruoli';de = 'Rollen'"),                           41, 42, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("ExchangePlans",                  NStr("ru = 'Планы обмена'; en = 'Exchange plans'; pl = 'Plany wymiany';es_ES = 'Planos de intercambio';es_CO = 'Planos de intercambio';tr = 'Değiştirme planları';it = 'Piani di scambio';de = 'Austauschpläne'"),                   43, 44, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("FilterCriteria",               NStr("ru = 'Критерии отбора'; en = 'Filter criteria'; pl = 'Filtruj kryteria';es_ES = 'Criterio de filtro';es_CO = 'Criterio de filtro';tr = 'Filtre kriteri';it = 'Criteri di filtro';de = 'Filterkriterien'"),                45, 46, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("EventSubscriptions",            NStr("ru = 'Подписки на события'; en = 'Event subscriptions'; pl = 'Subskrypcja wydarzeń';es_ES = 'Suscripción a eventos';es_CO = 'Suscripción a eventos';tr = 'Etkinlik abonelikleri';it = 'Notifiche degli eventi';de = 'Abonnement für Ereignisse'"),            47, 48, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("ScheduledJobs",          NStr("ru = 'Регламентные задания'; en = 'Scheduled jobs'; pl = 'Zadania zaplanowane';es_ES = 'Tareas programadas';es_CO = 'Tareas programadas';tr = 'Planlanan işler';it = 'Processi pianificati';de = 'Geplante Aufträge'"),           49, 50, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("FunctionalOptions",          NStr("ru = 'Функциональные опции'; en = 'Functional options'; pl = 'Opcje funkcjonalne';es_ES = 'Opciones funcionales';es_CO = 'Opciones funcionales';tr = 'İşlevsel opsiyonlar';it = 'Opzioni funzionali';de = 'Funktionale Optionen'"),           51, 52, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("FunctionalOptionsParameters", NStr("ru = 'Параметры функциональных опций'; en = 'Functional option parameters'; pl = 'Parametry opcji funkcjonalnych';es_ES = 'Parámetros de la opción funcional';es_CO = 'Parámetros de la opción funcional';tr = 'İşlevsel opsiyon parametreleri';it = 'Parametri delle opzioni funzionali';de = 'Funktionale Optionsparameter'"), 53, 54, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("SettingsStorages",            NStr("ru = 'Хранилища настроек'; en = 'Settings storages'; pl = 'Ustawianie pamięci';es_ES = 'Almacenamiento de configuraciones';es_CO = 'Almacenamiento de configuraciones';tr = 'Depolama alanı ayarı';it = 'Repository delle impostazioni';de = 'Speicherplatz einstellen'"),             55, 56, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("CommonForms",                   NStr("ru = 'Общие формы'; en = 'Common forms'; pl = 'Wspólne formularze';es_ES = 'Formularios comunes';es_CO = 'Formularios comunes';tr = 'Ortak formlar';it = 'Form comuni';de = 'Allgemeine Formulare'"),                    57, 58, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("CommonCommands",                 NStr("ru = 'Общие команды'; en = 'Common commands'; pl = 'Typowe polecenia';es_ES = 'Comandos comunes';es_CO = 'Comandos comunes';tr = 'Ortak komutlar';it = 'Comandi comuni';de = 'Allgemeine Befehle'"),                  59, 60, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("CommandGroups",                 NStr("ru = 'Группы команд'; en = 'Command groups'; pl = 'Grupy poleceń';es_ES = 'Grupos comunes';es_CO = 'Grupos comunes';tr = 'Ortak gruplar';it = 'Gruppi comando';de = 'Befehlsgruppen'"),                  61, 62, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("Interfaces",                   NStr("ru = 'Интерфейсы'; en = 'Interfaces'; pl = 'Interfejsy';es_ES = 'Interfaces';es_CO = 'Interfaces';tr = 'Arayüzler';it = 'Interfacce';de = 'Schnittstellen'"),                     63, 64, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("CommonTemplates",                  NStr("ru = 'Общие макеты'; en = 'Common templates'; pl = 'Wspólne szablony';es_ES = 'Modelos comunes';es_CO = 'Modelos comunes';tr = 'Ortak şablonlar';it = 'Template comuni';de = 'Allgemeine Vorlagen'"),                   65, 66, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("CommonPictures",                NStr("ru = 'Общие картинки'; en = 'Common pictures'; pl = 'Wspólne obrazy';es_ES = 'Imágenes comunes';es_CO = 'Imágenes comunes';tr = 'Ortak resimler';it = 'Immagini comuni';de = 'Allgemeine Bilder'"),                 67, 68, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("XDTOPackages",                   NStr("ru = 'XDTO-пакеты'; en = 'XDTO packages'; pl = 'Pakiety XDTO';es_ES = 'Paquetes XDTO';es_CO = 'Paquetes XDTO';tr = 'XDTO-paketleri';it = 'XDTO-packages';de = 'XDTO-Pakete'"),                    69, 70, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("WebServices",                   NStr("ru = 'Web-сервисы'; en = 'Web services'; pl = 'Serwisy Web';es_ES = 'Servicios Web';es_CO = 'Servicios Web';tr = 'Web servisleri';it = 'Servizi web';de = 'Web-Services'"),                    71, 72, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("WSReferences",                     NStr("ru = 'WS-ссылки'; en = 'WS references'; pl = 'WS-references';es_ES = 'Referencias WS';es_CO = 'Referencias WS';tr = 'WS referanslar';it = 'Riferimenti WS';de = 'WS Referenzen'"),                      73, 74, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("Styles",                        NStr("ru = 'Стили'; en = 'Styles'; pl = 'Style';es_ES = 'Diseños';es_CO = 'Diseños';tr = 'Stiller';it = 'Stili';de = 'Arten'"),                          75, 76, True, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("Languages",                        NStr("ru = 'Языки'; en = 'Languages'; pl = 'Języki';es_ES = 'Idiomas';es_CO = 'Idiomas';tr = 'Diller';it = 'Lingue';de = 'Sprachen'"),                          77, 78, True, MetadataObjectsCollections);
	
	MetadataObjectCollections_NewRow("Constants",                    NStr("ru = 'Константы'; en = 'Constants'; pl = 'Stałe';es_ES = 'Constantes';es_CO = 'Constantes';tr = 'Sabitler';it = 'Costanti';de = 'Konstanten'"),                      PictureLib.Constant,              PictureLib.Constant,                    False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("Catalogs",                  NStr("ru = 'Справочники'; en = 'Catalogs'; pl = 'Katalogi';es_ES = 'Catálogos';es_CO = 'Catálogos';tr = 'Ana kayıtlar';it = 'Anagrafiche';de = 'Kataloge'"),                    PictureLib.Catalog,             PictureLib.Catalog,                   False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("Documents",                    NStr("ru = 'Документы'; en = 'Documents'; pl = 'Dokumenty';es_ES = 'Documentos';es_CO = 'Documentos';tr = 'Belgeler';it = 'Documenti';de = 'Dokumente'"),                      PictureLib.Document,               PictureLib.DocumentObject,               False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("DocumentJournals",            NStr("ru = 'Журналы документов'; en = 'Document journals'; pl = 'Dzienniki wydarzeń dokumentu';es_ES = 'Registros del documento';es_CO = 'Registros del documento';tr = 'Belge günlükleri';it = 'Registro documenti';de = 'Dokumentprotokolle'"),             PictureLib.DocumentJournal,       PictureLib.DocumentJournal,             False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("Enums",                 NStr("ru = 'Перечисления'; en = 'Enumerations'; pl = 'Przelewy';es_ES = 'Transferencias';es_CO = 'Transferencias';tr = 'Transferler';it = 'Enumerazioni';de = 'Transfers'"),                   PictureLib.Enum,           PictureLib.Enum,                 False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("Reports",                       NStr("ru = 'Отчеты'; en = 'Reports'; pl = 'Sprawozdania';es_ES = 'Informes';es_CO = 'Informes';tr = 'Raporlar';it = 'Reports';de = 'Berichte'"),                         PictureLib.Report,                  PictureLib.Report,                        False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("DataProcessors",                    NStr("ru = 'Обработки'; en = 'Data processors'; pl = 'Opracowania';es_ES = 'Procesadores de datos';es_CO = 'Procesadores de datos';tr = 'Veri işlemcileri';it = 'Elaboratori di dati';de = 'Datenverarbeiter'"),                      PictureLib.DataProcessor,              PictureLib.DataProcessor,                    False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("ChartsOfCharacteristicTypes",      NStr("ru = 'Планы видов характеристик'; en = 'Charts of characteristic types'; pl = 'Plany rodzajów charakterystyk';es_ES = 'Diagramas de los tipos de características';es_CO = 'Diagramas de los tipos de características';tr = 'Özellik türü listeleri';it = 'Grafici di tipi caratteristiche';de = 'Diagramme von charakteristischen Typen'"),      PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("ChartsOfAccounts",                  NStr("ru = 'Планы счетов'; en = 'Charts of accounts'; pl = 'Plany kont';es_ES = 'Diagramas de las cuentas';es_CO = 'Diagramas de las cuentas';tr = 'Hesap planları';it = 'Piani dei conti';de = 'Kontenpläne'"),                   PictureLib.ChartOfAccounts,             PictureLib.ChartOfAccountsObject,             False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("ChartsOfCalculationTypes",            NStr("ru = 'Планы видов характеристик'; en = 'Charts of characteristic types'; pl = 'Plany rodzajów charakterystyk';es_ES = 'Diagramas de los tipos de características';es_CO = 'Diagramas de los tipos de características';tr = 'Özellik türü listeleri';it = 'Grafici di tipi caratteristiche';de = 'Diagramme von charakteristischen Typen'"),      PictureLib.ChartOfCharacteristicTypes, PictureLib.ChartOfCharacteristicTypesObject, False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("InformationRegisters",             NStr("ru = 'Регистры сведений'; en = 'Information registers'; pl = 'Rejestry informacji';es_ES = 'Registros de información';es_CO = 'Registros de información';tr = 'Bilgi kayıtları';it = 'Registri informazione';de = 'Informationsregister'"),              PictureLib.InformationRegister,        PictureLib.InformationRegister,              False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("AccumulationRegisters",           NStr("ru = 'Регистры накопления'; en = 'Accumulation registers'; pl = 'Rejestry akumulacji';es_ES = 'Registros de acumulación';es_CO = 'Registros de acumulación';tr = 'Birikim kayıtları';it = 'Registri di accumulo';de = 'Akkumulationsregister'"),            PictureLib.AccumulationRegister,      PictureLib.AccumulationRegister,            False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("AccountingRegisters",          NStr("ru = 'Регистры бухгалтерии'; en = 'Accounting registers'; pl = 'Rejestry księgowe';es_ES = 'Registros de contabilidad';es_CO = 'Registros de contabilidad';tr = 'Muhasebe kayıtları';it = 'Registri contabili';de = 'Buchhaltungsregister'"),           PictureLib.AccountingRegister,     PictureLib.AccountingRegister,           False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("CalculationRegisters",              NStr("ru = 'Регистры расчета'; en = 'Calculation registers'; pl = 'Rejestry obliczeń';es_ES = 'Registros de cálculos';es_CO = 'Registros de cálculos';tr = 'Hesaplama kayıtları';it = 'Registri di calcolo';de = 'Berechnungsregister'"),               PictureLib.CalculationRegister,         PictureLib.CalculationRegister,               False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("BusinessProcesses",               NStr("ru = 'Бизнес-процессы'; en = 'Business processes'; pl = 'Procesy biznesowe';es_ES = 'Procesos de negocio';es_CO = 'Procesos de negocio';tr = 'İş süreçleri';it = 'Processi di business';de = 'Geschäftsprozesse'"),                PictureLib.BusinessProcess,          PictureLib.BusinessProcessObject,          False, MetadataObjectsCollections);
	MetadataObjectCollections_NewRow("Tasks",                       NStr("ru = 'Задач'; en = 'Tasks'; pl = 'Zadania';es_ES = 'Tareas';es_CO = 'Tareas';tr = 'Görevler';it = 'Compiti';de = 'Aufgaben'"),                         PictureLib.Task,                 PictureLib.TaskObject,                 False, MetadataObjectsCollections);
	
	// Creating the predefined items.
	ItemParameters = MetadataObjectTreeItemParameters();
	ItemParameters.Name = Metadata.Name;
	ItemParameters.Synonym = Metadata.Synonym;
	ItemParameters.Picture = 79;
	ItemParameters.Parent = MetadataObjectsTree;
	ConfigurationItem = NewTreeRow(ItemParameters);
	
	ItemParameters = MetadataObjectTreeItemParameters();
	ItemParameters.Name = "Common";
	ItemParameters.Synonym = "Common";
	ItemParameters.Picture = 0;
	ItemParameters.Parent = ConfigurationItem;
	ItemCommon = NewTreeRow(ItemParameters);
	
	// FIlling the metadata object tree.
	For Each Row In MetadataObjectsCollections Do
		If Parameters.MetadataObjectsToSelectCollection.Count() = 0
			Or Parameters.MetadataObjectsToSelectCollection.FindByValue(Row.Name) <> Undefined Then
			Row.Parent = ?(Row.IsCommonCollection, ItemCommon, ConfigurationItem);
			AddMetadataObjectTreeItem(Row, ?(Row.Name = "Subsystems", Metadata.Subsystems, Undefined));
		EndIf;
	EndDo;
	
	If ItemCommon.GetItems().Count() = 0 Then
		ConfigurationItem.GetItems().Delete(ItemCommon);
	EndIf;
	
EndProcedure

// Returns a new metadata object tree item parameter structure.
//
// Returns:
//   Structure containing fields:
//     Name           - String - name of the parent item.
//     Synonym       - String - synonym of the parent item.
//     Mark       - Boolean - the initial mark of a collection or metadata object.
//     Picture      - Number - code of the parent item picture.
//     ObjectPicture - Number  - code of the subitem picture.
//     Parent        - reference to the value tree item that is a root of the item to be added.
//                       
//
&AtServer
Function MetadataObjectTreeItemParameters()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Name", "");
	ParametersStructure.Insert("FullName", "");
	ParametersStructure.Insert("Synonym", "");
	ParametersStructure.Insert("Check", 0);
	ParametersStructure.Insert("Picture", 0);
	ParametersStructure.Insert("ObjectPicture", Undefined);
	ParametersStructure.Insert("Parent", Undefined);
	
	Return ParametersStructure;
	
EndFunction

// Adds a new row to the form value tree and fills the full row set from metadata by the passed 
// parameter.
//
// If the Subsystems parameter is filled, the function is called recursively for all child subsystems.
//
// Parameters:
//   ItemParameters - Structure containing fields:
//     Name           - String - name of the parent item.
//     Synonym       - String - synonym of the parent item.
//     Mark       - Boolean - the initial mark of a collection or metadata object.
//     Picture      - Number - code of the parent item picture.
//     ObjectPicture - Number  - code of the subitem picture.
//     Parent        - reference to the value tree item that is a root of the item to be added.
//                       
//   Subsystems      - If filled, it contains Metadata.Subsystems value (an item collection).
//   Check       - Boolean - indicates whether a check for subordination to parent subsystems is required.
// 
// Returns:
// 
//   Metadata object tree row.
//
&AtServer
Function AddMetadataObjectTreeItem(ItemParameters, Subsystems = Undefined, CheckSSL = True)
	
	// Checking whether command interface is available in tree leaves only.
	If Subsystems <> Undefined  AND Parameters.Property("SubsystemsWithCIOnly") 
		AND Not IsBlankString(ItemParameters.FullName) 
		AND ItemsOfSubsystemsWithCommandInterface.FindByValue(ItemParameters.FullName) = Undefined Then
		Return Undefined;
	EndIf;
	
	If Subsystems = Undefined Then
		
		If Metadata[ItemParameters.Name].Count() = 0 Then
			
			// There are no metadata objects in the current tree branch.
			// For example, if there are no accounting registers, the Accounting registers root should not be 
			// added.
			Return Undefined;
			
		EndIf;
		
		NewRow = NewTreeRow(ItemParameters, Subsystems <> Undefined AND Subsystems <> Metadata.Subsystems);
		
		For Each MetadataCollectionItem In Metadata[ItemParameters.Name] Do
			
			If Parameters.FilterByMetadataObjects.Count() > 0
				AND Parameters.FilterByMetadataObjects.FindByValue(MetadataCollectionItem.FullName()) = Undefined Then
				Continue;
			EndIf;
			
			ItemParameters = MetadataObjectTreeItemParameters();
			ItemParameters.Name = MetadataCollectionItem.Name;
			ItemParameters.FullName = MetadataCollectionItem.FullName();
			ItemParameters.Synonym = MetadataCollectionItem.Synonym;
			ItemParameters.ObjectPicture = ItemParameters.ObjectPicture;
			ItemParameters.Parent = NewRow;
			NewTreeRow(ItemParameters, True);
		EndDo;
		
		Return NewRow;
		
	EndIf;
		
	If Subsystems.Count() = 0 AND ItemParameters.Name = "Subsystems" Then
		// If no subsystems are found, the Subsystems root should not be added.
		Return Undefined;
	EndIf;
	
	NewRow = NewTreeRow(ItemParameters, Subsystems <> Undefined AND Subsystems <> Metadata.Subsystems);
	
	For Each MetadataCollectionItem In Subsystems Do
		
		If Not CheckSSL
			Or Parameters.ParentSubsystems.Count() = 0
			Or Parameters.ParentSubsystems.FindByValue(MetadataCollectionItem.Name) <> Undefined Then
			
			ItemParameters = MetadataObjectTreeItemParameters();
			ItemParameters.Name = MetadataCollectionItem.Name;
			ItemParameters.FullName = MetadataCollectionItem.FullName();
			ItemParameters.Synonym = MetadataCollectionItem.Synonym;
			ItemParameters.Picture = ItemParameters.Picture;
			ItemParameters.ObjectPicture = ItemParameters.ObjectPicture;
			ItemParameters.Parent = NewRow;
			AddMetadataObjectTreeItem(ItemParameters, MetadataCollectionItem.Subsystems, False);
		EndIf;
	EndDo;
	
	Return NewRow;
	
EndFunction

&AtServer
Function NewTreeRow(RowParameters, IsMetadataObject = False)
	
	Collection = RowParameters.Parent.GetItems();
	NewRow = Collection.Add();
	NewRow.Name                 = RowParameters.Name;
	NewRow.Presentation       = ?(ValueIsFilled(RowParameters.Synonym), RowParameters.Synonym, RowParameters.Name);
	NewRow.Check             = ?(Parameters.SelectedMetadataObjects.FindByValue(RowParameters.FullName) = Undefined, 0, 1);
	NewRow.Picture            = RowParameters.Picture;
	NewRow.FullName           = RowParameters.FullName;
	NewRow.IsMetadataObject = IsMetadataObject;
	
	If NewRow.IsMetadataObject 
		AND NewRow.FullName = ChoiceInitialValue Then
		CurrentLineIDOnOpen = NewRow.GetID();
	EndIf;
	
	Return NewRow;
	
EndFunction

// Adds a new row to configuration metadata object type value table.
// 
//
// Parameters:
// Name           - a metadata object name, or a metadata object kind name.
// Synonym       - a metadata object synonym.
// Picture       - picture referring to the metadata object or to the metadata object type.
//                 
// IsCommonCollection - indicates whether the current item contains subitems.
//
&AtServer
Procedure MetadataObjectCollections_NewRow(Name, Synonym, Picture, ObjectPicture, IsCommonCollection, Tab)
	
	NewRow = Tab.Add();
	NewRow.Name               = Name;
	NewRow.Synonym           = Synonym;
	NewRow.Picture          = Picture;
	NewRow.ObjectPicture   = ObjectPicture;
	NewRow.IsCommonCollection = IsCommonCollection;
	
EndProcedure

// Recursively sets or clears mark for parent items of the passed item.
//
// Parameters:
// Element      - FormDataTreeItemCollection.
//
&AtClient
Procedure MarkParentItems(Item)

	Parent = Item.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ParentItems = Parent.GetItems();
	If ParentItems.Count() = 0 Then
		Parent.Check = 0;
	ElsIf Item.Check = 2 Then
		Parent.Check = 2;
	Else
		Parent.Check = ItemMarkValues(ParentItems);
	EndIf;
	
	MarkParentItems(Parent);
	
EndProcedure

&AtClient
Function ItemMarkValues(ParentItems)
	
	HasMarkedItems    = False;
	HasUnmarkedItems = False;
	
	For each ParentItem In ParentItems Do
		
		If ParentItem.Check = 2 OR (HasMarkedItems AND HasUnmarkedItems) Then
			HasMarkedItems    = True;
			HasUnmarkedItems = True;
			Break;
		ElsIf ParentItem.IsMetadataObject Then
			HasMarkedItems    = HasMarkedItems    OR    ParentItem.Check;
			HasUnmarkedItems = HasUnmarkedItems OR NOT ParentItem.Check;
		Else
			NestedItems = ParentItem.GetItems();
			If NestedItems.Count() = 0 Then
				Continue;
			EndIf;
			NestedItemMarkValue = ItemMarkValues(NestedItems);
			HasMarkedItems    = HasMarkedItems    OR    ParentItem.Check OR    NestedItemMarkValue;
			HasUnmarkedItems = HasUnmarkedItems OR NOT ParentItem.Check OR NOT NestedItemMarkValue;
		EndIf;
	EndDo;
	
	If HasMarkedItems Then
		If HasUnmarkedItems Then
			Return 2;
		Else
			If SubsystemsWithCIOnly Then
				Return 2;
			Else
				Return 1;
			EndIf;
		EndIf;
	Else
		Return 0;
	EndIf;
	
EndFunction

&AtServer
Procedure MarkParentItemsAtServer(Item)

	Parent = Item.GetParent();
	
	If Parent = Undefined Then
		Return;
	EndIf;
	
	ParentItems = Parent.GetItems();
	If ParentItems.Count() = 0 Then
		Parent.Check = 0;
	ElsIf Item.Check = 2 Then
		Parent.Check = 2;
	Else
		Parent.Check = ItemMarkValuesAtServer(ParentItems);
	EndIf;
	
	MarkParentItemsAtServer(Parent);

EndProcedure

&AtServer
Function ItemMarkValuesAtServer(ParentItems)
	
	HasMarkedItems    = False;
	HasUnmarkedItems = False;
	
	For each ParentItem In ParentItems Do
		
		If ParentItem.Check = 2 OR (HasMarkedItems AND HasUnmarkedItems) Then
			HasMarkedItems    = True;
			HasUnmarkedItems = True;
			Break;
		ElsIf ParentItem.IsMetadataObject Then
			HasMarkedItems    = HasMarkedItems    OR    ParentItem.Check;
			HasUnmarkedItems = HasUnmarkedItems OR NOT ParentItem.Check;
		Else
			NestedItems = ParentItem.GetItems();
			If NestedItems.Count() = 0 Then
				Continue;
			EndIf;
			NestedItemMarkValue = ItemMarkValuesAtServer(NestedItems);
			HasMarkedItems    = HasMarkedItems    OR    ParentItem.Check OR    NestedItemMarkValue;
			HasUnmarkedItems = HasUnmarkedItems OR NOT ParentItem.Check OR NOT NestedItemMarkValue;
		EndIf;
	EndDo;
	
	Return ?(HasMarkedItems AND HasUnmarkedItems, 2, ?(HasMarkedItems, 1, 0));
	
EndFunction

// Selects a mark of the metadata object collections that does not have metadata objects or whose 
// metadata object marks are selected.
// 
//
// Parameters:
// Element      - FormDataTreeItemCollection.
//
&AtServer
Procedure SetInitialCollectionMark(Parent)
	
	NestedItems = Parent.GetItems();
	
	For Each NestedItem In NestedItems Do
		If NestedItem.Check Then
			MarkParentItemsAtServer(NestedItem);
		EndIf;
		SetInitialCollectionMark(NestedItem);
	EndDo;
	
EndProcedure

// The procedure recursively sets or clears mark for nested items of starting with the passed item.
// 
//
// Parameters:
// Element      - FormDataTreeItemCollection.
//
&AtClient
Procedure SetNestedItemMarks(Item)

	NestedItems = Item.GetItems();
	
	If NestedItems.Count() = 0 Then
		If Not Item.IsMetadataObject Then
			Item.Check = 0;
		EndIf;
	Else
		For Each NestedItem In NestedItems Do
			If Not SubsystemsWithCIOnly Then
				NestedItem.Check = Item.Check;
			EndIf;
			SetNestedItemMarks(NestedItem);
		EndDo;
	EndIf;
	
EndProcedure

// Fills a list with the selected tree items.
// The function recursively scans the item tree and if an item is selected adds its FullName to the 
// selected list.
//
// Parent      - FormDataTreeItem
//
&AtServer
Procedure GetData(Parent = Undefined)
	
	Parent = ?(Parent = Undefined, MetadataObjectsTree, Parent);
	
	ItemCollection = Parent.GetItems();
	
	For Each Item In ItemCollection Do
		If Item.Check = 1 AND Not IsBlankString(Item.FullName) Then
			SelectedMetadataObjects.Add(Item.FullName, Item.Presentation);
		EndIf;
		GetData(Item);
	EndDo;
	
EndProcedure

#EndRegion
