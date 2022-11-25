#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Parameters.PathToSubsystem) Then
		Parameters.PathToSubsystem = ReportsOptionsClientServer.HomePageID();
	EndIf;
	
	ClientParameters = ReportsOptions.ClientParameters();
	ClientParameters.Insert("PathToSubsystem", Parameters.PathToSubsystem);
	
	QuickAccessPicture = PictureLib.QuickAccess;
	HiddenOptionsColor = StyleColors.ReportHiddenColorVariant;
	VisibleOptionsColor = StyleColors.HyperlinkColor;
	SearchResultsHighlightColor = WebColors.Yellow;
	TooltipColor = StyleColors.NoteText;
	
	If ClientApplication.CurrentInterfaceVariant() = ClientApplicationInterfaceVariant.Version8_2 Then
		Items.CommandBar.Width = 25;
		Items.SearchString.Width = 35;
		ReportsOptionsGroupColor = StyleColors.ReportOptionsGroupColor82;
		ImportantGroupFont  = New Font("MS Shell Dlg", 10, True, False, False, False, 100);
		NormalGroupFont = New Font("MS Shell Dlg", 8, True, False, False, False, 100);
		SectionFont       = New Font("MS Shell Dlg", 12, True, False, False, False, 100);
		ImportantLabelFont = New Font(, , True);
	Else // Taxi.
		ReportsOptionsGroupColor = StyleColors.ReportOptionsGroupColor;
		ImportantGroupFont  = New Font("Arial", 12, False, False, False, False, 100);
		NormalGroupFont = New Font("Arial", 12, False, False, False, False, 90);
		SectionFont       = New Font("Arial", 12, True, False, False, False, 100);
		ImportantLabelFont = New Font("Arial", 10, True, False, False, False, 100);
	EndIf;
	If Not AccessRight("SaveUserData", Metadata) Then
		Items.Customize.Visible = False;
		Items.ResetMySettings.Visible = False;
	EndIf;
	
	GlobalSettings = ReportsOptions.GlobalSettings();
	Items.SearchString.InputHint = GlobalSettings.Search.InputHint;
	
	MobileApplicationDescription = CommonClientServer.StructureProperty(GlobalSettings, "MobileApplicationDescription");
	If MobileApplicationDescription = Undefined Then
		Items.MobileApplicationDescription.Visible = False;
	Else
		ClientParameters.Insert("MobileApplicationDescription", MobileApplicationDescription);
	EndIf;
	
	SectionColor = ReportsOptionsGroupColor;
	
	Items.QuickAccessHeaderLabel.Font      = ImportantGroupFont;
	Items.QuickAccessHeaderLabel.TextColor = ReportsOptionsGroupColor;
	Items.SeeAlso.TitleFont      = ImportantGroupFont;
	Items.SeeAlso.TitleTextColor = ReportsOptionsGroupColor;
	
	FillInInfoOnSubsystemsAndSetTitle();
	
	SetOfAttributes = GetAttributes();
	For Each Attribute In SetOfAttributes Do
		ConstantAttributes.Add(Attribute.Name);
	EndDo;
	
	For Each Command In Commands Do
		ConstantCommands.Add(Command.Name);
	EndDo;
	
	Items.SearchInAllSections.Visible = ValueIsFilled(SearchString);
	
	// Read a user setting that is common for all report panels.
	ImportAllSettings();
	
	If Parameters.Property("SearchString") Then
		SearchString = Parameters.SearchString;
	EndIf;
	If Parameters.Property("SearchInAllSections") Then
		SearchInAllSections = Parameters.SearchInAllSections;
	EndIf;
	
	// Fill in a panel.
	UpdateReportPanelAtServer();
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	#If WebClient Then
		WebClient = True;
	#Else
		WebClient = False;
	#EndIf
	If ShowTooltipsNotification AND ShowTooltips Then
		ShowUserNotification(
			NStr("ru = 'Новая возможность'; en = 'New feature'; pl = 'Nowa możliwość';es_ES = 'Nueva posibilidad';es_CO = 'Nueva posibilidad';tr = 'Yeni imkan';it = 'Nuova funzionalità';de = 'Neue Möglichkeiten'"),
			"e1cib/data/SettingsStorage.ReportsVariantsStorage.Form.DetailsDisplayNewFeatureDetails",
			NStr("ru = 'Вывод описаний в панелях отчетов'; en = 'Display descriptions in report panels'; pl = 'Pokazywanie opisów w panelach sprawozdań';es_ES = 'Mostrar las descripciones en las barras de informes';es_CO = 'Mostrar las descripciones en las barras de informes';tr = 'Rapor panellerindeki açıklamaları görüntüleme';it = 'Mostra descrizioni nei pannelli report';de = 'Zeigt Beschreibungen in Berichtsbereichen an'"),
			PictureLib.Information32);
	EndIf;
EndProcedure

&AtClient
Procedure OnReopen()
	If SetupMode Or ValueIsFilled(SearchString) Then
		SetupMode = False;
		SearchString = "";
		UpdateReportPanelAtClient("OnReopen");
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If Source = ThisObject Then
		Return;
	EndIf;
	If ClientParameters.Property("Update") Then
		DetachIdleHandler("UpdateReportPanelByTimer");
	Else
		ClientParameters.Insert("Update", False)
	EndIf;
	If EventName = ReportsOptionsClientServer.EventNameChangingOption()
		Or EventName = "Write_ConstantsSet" Then
		ClientParameters.Update = True;
	ElsIf EventName = ReportsOptionsClientServer.EventNameChangingCommonSettings() Then
		If Parameter.ShowTooltips <> ShowTooltips
			Or Parameter.SearchInAllSections <> SearchInAllSections Then
			ClientParameters.Update = True;
		EndIf;
		FillPropertyValues(ThisObject, Parameter, "ShowTooltips, SearchInAllSections, ShowTooltipsNotification");
	EndIf;
	If ClientParameters.Update Then
		AttachIdleHandler("UpdateReportPanelByTimer", 1, True);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure Attachable_OptionClick(Item)
	Option = FindOptionByItemName(Item.Name);
	If Option = Undefined Then
		Return;
	EndIf;
	ReportFormParameters = New Structure;
	Subsystem = FindSubsystemByRef(ThisObject, Option.Subsystem);
	If Subsystem.VisibleOptionsCount > 1 Then
		ReportFormParameters.Insert("Subsystem", Option.Subsystem);
	EndIf;
	ReportsOptionsClient.OpenReportForm(ThisObject, Option, ReportFormParameters);
EndProcedure

&AtClient
Procedure Attachable_OptionVisibilityOnChange(Item)
	CheckBox = Item;
	Show = ThisObject[CheckBox.Name];
	
	LabelName = Mid(CheckBox.Name, StrLen("CheckBox_")+1);
	Option = FindOptionByItemName(LabelName);
	Item = Items.Find(LabelName);
	If Option = Undefined Or Item = Undefined Then
		Return;
	EndIf;
	
	ShowHideOption(Option, Item, Show);
EndProcedure

&AtClient
Procedure SearchStringTextEditEnd(Item, Text, ChoiceData, DataGetParameters, StandardProcessing)
	If Not IsBlankString(Text) AND SearchStringIsTooShort(Text) Then
		StandardProcessing = False;
	EndIf;
EndProcedure

&AtClient
Function SearchStringIsTooShort(Text)
	Text = TrimAll(Text);
	If StrLen(Text) < 2 Then
		ShowMessageBox(, NStr("ru = 'Введена слишком короткая строка поиска.'; en = 'Search string is too short.'; pl = 'Wprowadzony zbyt krótki ciąg wyszukiwania';es_ES = 'Línea de búsqueda es demasiado corta.';es_CO = 'Línea de búsqueda es demasiado corta.';tr = 'Arama dizesi çok kısa.';it = 'La stringa di ricerca è troppo corta.';de = 'Suchzeichenfolge ist zu kurz.'"));
		Return True;
	EndIf;
	
	HasNormalWord = False;
	WordArray = ReportsOptionsClientServer.ParseSearchStringIntoWordArray(Text);
	For Each Word In WordArray Do
		If StrLen(Word) >= 2 Then
			HasNormalWord = True;
			Break;
		EndIf;
	EndDo;
	If Not HasNormalWord Then
		ShowMessageBox(, NStr("ru = 'Введены слишком короткие слова для поиска.'; en = 'Words for search are too short.'; pl = 'Słowa do wyszukania są za krótkie.';es_ES = 'Palabras de búsqueda son demasiado cortas.';es_CO = 'Palabras de búsqueda son demasiado cortas.';tr = 'Arama için kelimeler çok kısa.';it = 'Hai inserito parole troppo brevi per la ricerca.';de = 'Wörter für die Suche sind zu kurz.'"));
		Return True;
	EndIf;
	
	Return False;
EndFunction

&AtClient
Procedure SearchStringOnChange(Item)
	If Not IsBlankString(SearchString) AND SearchStringIsTooShort(SearchString) Then
		SearchString = "";
		CurrentItem = Items.SearchString;
		Return;
	EndIf;
	
	UpdateReportPanelAtClient("SearchStringOnChange");
	
	If ValueIsFilled(SearchString) Then
		CurrentItem = Items.SearchString;
	EndIf;
EndProcedure

&AtClient
Procedure SearchInAllSectionsOnChange(Item)
	If ValueIsFilled(SearchString) Then
		UpdateReportPanelAtClient("SearchInAllSectionsOnChange");
		
		CommonSettings = New Structure;
		CommonSettings.Insert("ShowTooltips",           ShowTooltips);
		CommonSettings.Insert("SearchInAllSections",          SearchInAllSections);
		CommonSettings.Insert("ShowTooltipsNotification", ShowTooltipsNotification);
		
		Notify(
			ReportsOptionsClientServer.EventNameChangingCommonSettings(),
			CommonSettings,
			ThisObject);
		
		CurrentItem = Items.RunSearch;
	Else
		CurrentItem = Items.SearchString;
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_SectionTitleClick(Item)
	SectionGroupName = Item.Parent.Name;
	Substrings = StrSplit(SectionGroupName, "_");
	SectionPriority = Substrings[1];
	FoundItems = ApplicationSubsystems.FindRows(New Structure("Priority", SectionPriority));
	If FoundItems.Count() = 0 Then
		Return;
	EndIf;
	Section = FoundItems[0];
	
	PathToSubsystem = StrReplace(Section.FullName, "Subsystem.", "");
	
	ParametersForm = New Structure;
	ParametersForm.Insert("PathToSubsystem",      PathToSubsystem);
	ParametersForm.Insert("SearchString",         SearchString);
	ParametersForm.Insert("SearchInAllSections", 0);
	
	OwnerForm     = ThisObject;
	FormUniqueness = True;
	
	If ClientParameters.RunMeasurements Then
		Msrmnt = StartMeasurement("ReportPanel.Opening", ClientParameters.MeasurementsPrefix + "; " + PathToSubsystem);
	EndIf;
	
	OpenForm("CommonForm.ReportPanel", ParametersForm, OwnerForm, FormUniqueness);
	
	If ClientParameters.RunMeasurements Then
		EndMeasurement(Msrmnt);
	EndIf;
EndProcedure

&AtClient
Procedure ShowTooltipsOnChange(Item)
	UpdateReportPanelAtClient("ShowTooltipsOnChange");
	
	CommonSettings = New Structure;
	CommonSettings.Insert("ShowTooltips",           ShowTooltips);
	CommonSettings.Insert("SearchInAllSections",          SearchInAllSections);
	CommonSettings.Insert("ShowTooltipsNotification", ShowTooltipsNotification);
	
	Notify(
		ReportsOptionsClientServer.EventNameChangingCommonSettings(),
		CommonSettings,
		ThisObject);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Customize(Command)
	SetupMode = Not SetupMode;
	UpdateReportPanelAtClient(?(SetupMode, "EnableSetupMode", "DisableSetupMode"));
EndProcedure

&AtClient
Procedure MoveToQuickAccess(Command)
	If WebClient Then
		Item = Items.Find(Mid(Command.Name, StrFind(Command.Name, "_")+1));
	Else
		Item = CurrentItem;
	EndIf;
	If TypeOf(Item) <> Type("FormDecoration") Then
		Return;
	EndIf;
	
	Option = FindOptionByItemName(Item.Name);
	If Option = Undefined Then
		Return;
	EndIf;
	
	AddRemoveOptionFromQuickAccess(Option, Item, True);
EndProcedure

&AtClient
Procedure RemoveFromQuickAccess(Command)
	If WebClient Then
		Item = Items.Find(Mid(Command.Name, StrFind(Command.Name, "_")+1));
	Else
		Item = CurrentItem;
	EndIf;
	If TypeOf(Item) <> Type("FormDecoration") Then
		Return;
	EndIf;
	
	Option = FindOptionByItemName(Item.Name);
	If Option = Undefined Then
		Return;
	EndIf;
	
	AddRemoveOptionFromQuickAccess(Option, Item, False);
EndProcedure

&AtClient
Procedure Change(Command)
	If WebClient Then
		Item = Items.Find(Mid(Command.Name, StrFind(Command.Name, "_")+1));
	Else
		Item = CurrentItem;
	EndIf;
	If TypeOf(Item) <> Type("FormDecoration") Then
		Return;
	EndIf;
	
	Option = FindOptionByItemName(Item.Name);
	If Option = Undefined Then
		Return;
	EndIf;
	
	ReportsOptionsClient.ShowReportSettings(Option.Ref);
EndProcedure

&AtClient
Procedure ClearSettings(Command)
	QuestionText = NStr("ru = 'Сбросить настройки расположения отчетов?'; en = 'Reset report placement settings?'; pl = 'Zresetować ustawienia rozmieszczania sprawozdań?';es_ES = '¿Restablecer las configuraciones de la colocación del informe?';es_CO = '¿Restablecer las configuraciones de la colocación del informe?';tr = 'Rapor yerleşimi ayarları sıfırlansın mı?';it = 'Ripristinare le impostazioni di posizionamento del report?';de = 'Einstellungen für die Berichtsplatzierung zurücksetzen?'");
	Handler = New NotifyDescription("ClearSettingsCompletion", ThisObject);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.No);
EndProcedure

&AtClient
Procedure AllReports(Command)
	ParametersForm = New Structure;
	If ValueIsFilled(SearchString) Then
		ParametersForm.Insert("SearchString", SearchString);
	EndIf;
	If ValueIsFilled(SearchString) AND Not SetupMode AND SearchInAllSections = 1 Then
		// Position on a tree root.
		SectionRef = PredefinedValue("Catalog.MetadataObjectIDs.EmptyRef");
	Else
		SectionRef = CurrentSectionRef;
	EndIf;
	ParametersForm.Insert("SectionRef", SectionRef);
	
	If ClientParameters.RunMeasurements Then
		Msrmnt = StartMeasurement("ReportsList.Opening");
	EndIf;
	
	OpenForm("Catalog.ReportsOptions.ListForm", ParametersForm, , "ReportsOptions.AllReports");
	
	If ClientParameters.RunMeasurements Then
		EndMeasurement(Msrmnt);
	EndIf;
EndProcedure

&AtClient
Procedure Update(Command)
	UpdateReportPanelAtClient("Refresh");
EndProcedure

&AtClient
Procedure RunSearch(Command)
	UpdateReportPanelAtClient("RunSearch");
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure ShowHideOption(Option, Item, Show)
	Option.Visible = Show;
	Item.TextColor = ?(Show, VisibleOptionsColor, HiddenOptionsColor);
	ThisObject["CheckBox_"+ Option.LabelName] = Show;
	If Option.Important Then
		If Show Then
			Item.Font = ImportantLabelFont;
		Else
			Item.Font = New Font;
		EndIf;
	EndIf;
	Subsystem = FindSubsystemByRef(ThisObject, Option.Subsystem);
	Subsystem.VisibleOptionsCount = Subsystem.VisibleOptionsCount + ?(Show, 1, -1);
	While Subsystem.Ref <> Subsystem.SectionRef Do
		Subsystem = FindSubsystemByRef(ThisObject, Subsystem.SectionRef);
		Subsystem.VisibleOptionsCount = Subsystem.VisibleOptionsCount + ?(Show, 1, -1);
	EndDo;
	SaveUserSettingsSSL(Option.Ref, Option.Subsystem, Option.Visible, Option.QuickAccess);
EndProcedure

&AtClient
Procedure AddRemoveOptionFromQuickAccess(Option, Item, QuickAccess)
	If Option.QuickAccess = QuickAccess Then
		Return;
	EndIf;
	
	// Register a result for writing.
	Option.QuickAccess = QuickAccess;
	
	// Related action: if the option to be added to the quick access list is hidden, showing this option.
	If QuickAccess AND Not Option.Visible Then
		ShowHideOption(Option, Item, True);
	EndIf;
	
	// Visual result
	MoveQuickAccessOption(Option.GetID(), QuickAccess);
EndProcedure

&AtClient
Procedure ClearSettingsCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		SetupMode = False;
		UpdateReportPanelAtClient("ClearSettings");
	EndIf;
EndProcedure

&AtClient
Procedure UpdateReportPanelByTimer()
	If ClientParameters.Update Then
		ClientParameters.Update = False;
		UpdateReportPanelAtClient("");
	EndIf;
EndProcedure

&AtClient
Procedure UpdateReportPanelAtClient(Event = "")
	If ClientParameters.RunMeasurements Then
		Msrmnt = StartMeasurement(Event);
	EndIf;
	
	UpdateReportPanelAtServer(Event);
	
	If ClientParameters.RunMeasurements Then
		EndMeasurement(Msrmnt);
	EndIf;
EndProcedure

&AtClient
Function StartMeasurement(Event, Comment = Undefined)
	If Comment = Undefined Then
		Comment = ClientParameters.MeasurementsPrefix;
	EndIf;
	
	Msrmnt = New Structure("Name, ID, ModulePerformanceMonitorClient");
	If Event = "ReportsList.Opening" Or Event = "ReportPanel.Opening" Then
		Msrmnt.Name = Event;
		Comment = Comment + "; " + NStr("ru = 'Из панели отчетов:'; en = 'From report panel:'; pl = 'Z panelu sprawozdań:';es_ES = 'De la barra de informes:';es_CO = 'De la barra de informes:';tr = 'Rapor panelinden:';it = 'Dal pannello report';de = 'Aus dem Berichtsfenster:'") + " " + ClientParameters.PathToSubsystem;
	Else
		If SetupMode Or Event = "DisableSetupMode" Then
			Msrmnt.Name = "ReportPanel.SetupMode";
		ElsIf ValueIsFilled(SearchString) Then
			Msrmnt.Name = "ReportPanel.Search"; // Search itself is interesting only in view mode.
		EndIf;
		Comment = Comment + "; " + ClientParameters.PathToSubsystem;
		Comment = Comment + "; " + NStr("ru = 'Подсказки:'; en = 'Tooltips:'; pl = 'Podpowiedzi:';es_ES = 'Pistas:';es_CO = 'Pistas:';tr = 'Araç ipuçları:';it = 'Consigli:';de = 'Hinweise:'") + " " + String(ShowTooltips);
	EndIf;
	
	If Msrmnt.Name = Undefined Then
		Return Undefined;
	EndIf;
	
	If ValueIsFilled(SearchString) Then
		Comment = Comment
			+ "; " + NStr("ru = 'Поиск:'; en = 'Search:'; pl = 'Wyszukiwanie:';es_ES = 'Búsqueda:';es_CO = 'Búsqueda:';tr = 'Arama:';it = 'Ricerca:';de = 'Suche:'") + " " + String(SearchString)
			+ "; " + NStr("ru = 'Во всех разделах:'; en = 'In all sections:'; pl = 'We wszystkich rozdziałach:';es_ES = 'En todas las secciones:';es_CO = 'En todas las secciones:';tr = 'Tüm bölümlerde:';it = 'In tutte le sezioni:';de = 'In allen Bereichen:'") + " " + String(SearchInAllSections);
	Else
		Comment = Comment + "; " + NStr("ru = 'Без поиска'; en = 'Without searching'; pl = 'Bez wyszukiwania';es_ES = 'Sin buscar';es_CO = 'Sin buscar';tr = 'Aramadan';it = 'Senza ricerca';de = 'Ohne Suche'");
	EndIf;
	
	If Event = "DisableSetupMode" Then
		Comment = Comment + "; " + NStr("ru = 'Выход из режима настройки'; en = 'Exit setup mode'; pl = 'Wyjście z trybu ustawień';es_ES = 'Salir del modo de ajustes';es_CO = 'Salir del modo de ajustes';tr = 'Ayarlar modundan çıkış';it = 'Esci da modalità setup';de = 'Verlassen des Einstellungsmodus'");
	EndIf;
	Msrmnt.ModulePerformanceMonitorClient = CommonClient.CommonModule("PerformanceMonitorClient");
	Msrmnt.ID = Msrmnt.ModulePerformanceMonitorClient.StartTimeMeasurement(True, Msrmnt.Name);
	Msrmnt.ModulePerformanceMonitorClient.SetMeasurementComment(Msrmnt.ID, Comment);
	Return Msrmnt;
EndFunction

&AtClient
Procedure EndMeasurement(Msrmnt)
	If Msrmnt <> Undefined Then
		Msrmnt.ModulePerformanceMonitorClient.StopTimeMeasurement(Msrmnt.ID);
	EndIf;
EndProcedure

&AtClient
Function FindOptionByItemName(LabelName)
	ID = QuickSearchForOptionsByItemName[LabelName];
	If ID <> Undefined Then
		Return AddedOptions.FindByID(ID);
	Else
		FoundItems = AddedOptions.FindRows(New Structure("LabelName", LabelName));
		If FoundItems.Count() = 1 Then
			Return FoundItems[0];
		EndIf;
	EndIf;
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtClientAtServerNoContext
Function FindSubsystemByRef(Form, Ref)
	ID = Form.QuickSearchForSubsystemsByRef[Ref];
	If ID <> Undefined Then
		Return Form.ApplicationSubsystems.FindByID(ID);
	Else
		FoundItems = Form.ApplicationSubsystems.FindRows(New Structure("Ref", Ref));
		If FoundItems.Count() = 1 Then
			Return FoundItems[0];
		EndIf;
	EndIf;
	Return Undefined;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServer
Procedure MoveQuickAccessOption(Val OptionID, Val QuickAccess)
	Option = AddedOptions.FindByID(OptionID);
	Item = Items.Find(Option.LabelName);
	
	If QuickAccess Then
		Item.Font = New Font;
		GroupForTransfer = SubgroupWithLeastNumberOfItems(Items.QuickAccess);
	ElsIf Option.SeeAlso Then
		Item.Font = New Font;
		GroupForTransfer = SubgroupWithLeastNumberOfItems(Items.SeeAlso);
	ElsIf Option.NoGroup Then
		Item.Font = ?(Option.Important, ImportantLabelFont, New Font);
		GroupForTransfer = SubgroupWithLeastNumberOfItems(Items.NoGroup);
	Else
		Item.Font = ?(Option.Important, ImportantLabelFont, New Font);
		Subsystem = FindSubsystemByRef(ThisObject, Option.Subsystem);
		
		GroupForTransfer = Items.Find(Subsystem.ItemName + "_1");
		If GroupForTransfer = Undefined Then
			Return;
		EndIf;
	EndIf;
	
	BeforeWhichItem = Undefined;
	If GroupForTransfer.ChildItems.Count() > 0 Then
		BeforeWhichItem = GroupForTransfer.ChildItems.Get(0);
	EndIf;
	
	Items.Move(Item.Parent, GroupForTransfer, BeforeWhichItem);
	
	If QuickAccess Then
		Items.QuickAccessTooltipWhenNotConfigured.Visible = False;
	Else
		QuickAccessOptions = AddedOptions.FindRows(New Structure("QuickAccess", True));
		If QuickAccessOptions.Count() = 0 Then
			Items.QuickAccessTooltipWhenNotConfigured.Visible = True;
		Else
			Items.QuickAccessTooltipWhenNotConfigured.Visible = False;
		EndIf;
	EndIf;
	
	CheckBoxName = "CheckBox_" + Option.LabelName;
	CheckBox = Items.Find(CheckBoxName);
	CheckBoxDisplayed = (CheckBox.Visible = True);
	If CheckBoxDisplayed = QuickAccess Then
		CheckBox.Visible = Not QuickAccess;
	EndIf;
	
	LabelContextMenu = Item.ContextMenu;
	If LabelContextMenu <> Undefined Then
		ButtonRemove = Items.Find("RemoveFromQuickAccess_" + Option.LabelName);
		ButtonRemove.Visible = QuickAccess;
		ButtonMove = Items.Find("MoveToQuickAccess_" + Option.LabelName);
		ButtonMove.Visible = Not QuickAccess;
	EndIf;
	
	SaveUserSettingsSSL(Option.Ref, Option.Subsystem, Option.Visible, Option.QuickAccess);
EndProcedure

&AtServer
Procedure UpdateReportPanelAtServer(Val Event = "")
	If Event = "ClearSettings" Then
		InformationRegisters.ReportOptionsSettings.ResetUserSettingsInSection(CurrentSectionRef);
	EndIf;
	
	If Event = "" Or Event = "SearchStringOnChange" Or Event = "ClearSettings" Then
		If ValueIsFilled(SearchString) Then
			ChoiceList = Items.SearchString.ChoiceList;
			ListItem = ChoiceList.FindByValue(SearchString);
			If ListItem = Undefined Then
				ChoiceList.Insert(0, SearchString);
				If ChoiceList.Count() > 10 Then
					ChoiceList.Delete(10);
				EndIf;
			Else
				Index = ChoiceList.IndexOf(ListItem);
				If Index <> 0 Then
					ChoiceList.Move(Index, -Index);
				EndIf;
			EndIf;
			If Event = "SearchStringOnChange" Then
				SaveSettingsOfThisReportPanel();
			EndIf;
		EndIf;
	ElsIf Event = "ShowTooltipsOnChange"
		Or Event = "SearchInAllSectionsOnChange" Then
		
		CommonSettings = New Structure;
		CommonSettings.Insert("ShowTooltips",           ShowTooltips);
		CommonSettings.Insert("SearchInAllSections",          SearchInAllSections);
		CommonSettings.Insert("ShowTooltipsNotification", ShowTooltipsNotification);
		
		ReportsOptions.SaveCommonPanelSettings(CommonSettings);
		
	EndIf;
	Items.SearchInAllSections.Visible = Not SetupMode AND ValueIsFilled(SearchString);
	
	Items.ShowTooltips.Visible = SetupMode;
	Items.QuickAccessHeaderLabel.ToolTipRepresentation = ?(SetupMode, ToolTipRepresentation.Button, ToolTipRepresentation.None);
	Items.SearchResultsFromOtherSectionsGroup.Visible = (SearchInAllSections = 1);
	Items.Customize.Check = SetupMode;
	
	// Title.
	SettingsModeSuffix = " (" + NStr("ru = 'настройка'; en = 'setting'; pl = 'ustawienia';es_ES = 'configuración';es_CO = 'configuración';tr = 'ayarlar';it = 'impostazione';de = 'einstellung'") + ")";
	SuffixDisplayed = (Right(Title, StrLen(SettingsModeSuffix)) = SettingsModeSuffix);
	If SuffixDisplayed <> SetupMode Then
		If SetupMode Then
			Title = Title + SettingsModeSuffix;
		Else
			Title = StrReplace(Title, SettingsModeSuffix, "");
		EndIf;
	EndIf;
	
	// Remove items.
	ClearFormRemovingAddedItems();
	
	// Delete commands
	If WebClient Then
		CommandsToDelete = New Array;
		For Each Command In Commands Do
			If ConstantCommands.FindByValue(Command.Name) = Undefined Then
				CommandsToDelete.Add(Command);
			EndIf;
		EndDo;
		For Each Command In CommandsToDelete Do
			Commands.Delete(Command);
		EndDo;
	EndIf;
	
	// Reset the number of the last added item.
	For Each TableRow In ApplicationSubsystems Do
		TableRow.ItemNumber = 0;
		TableRow.VisibleOptionsCount = 0;
	EndDo;
	
	// Fill in a report panel
	FillInReportPanel();
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure ClearFormRemovingAddedItems()
	ItemsToRemove = New Array;
	For Each Level3Item In Items.QuickAccess.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			ItemsToRemove.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level3Item In Items.NoGroup.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			ItemsToRemove.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level3Item In Items.WithGroup.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			ItemsToRemove.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level3Item In Items.SeeAlso.ChildItems Do
		For Each Level4Item In Level3Item.ChildItems Do
			ItemsToRemove.Add(Level4Item);
		EndDo;
	EndDo;
	For Each Level4Item In Items.SearchResultsFromOtherSections.ChildItems Do
		ItemsToRemove.Add(Level4Item);
	EndDo;
	For Each ItemToRemove In ItemsToRemove Do
		Items.Delete(ItemToRemove);
	EndDo;
EndProcedure

&AtServerNoContext
Procedure SaveUserSettingsSSL(Option, Subsystem, Visibility, QuickAccess)
	SettingsPackage = New ValueTable;
	SettingsPackage.Add();
	Dimensions = New Structure;
	Dimensions.Insert("User", Users.AuthorizedUser());
	Dimensions.Insert("Variant", Option);
	Dimensions.Insert("Subsystem", Subsystem);
	Resources = New Structure;
	Resources.Insert("Visible", Visibility);
	Resources.Insert("QuickAccess", QuickAccess);
	InformationRegisters.ReportOptionsSettings.WriteSettingsPackage(SettingsPackage, Dimensions, Resources, True);
EndProcedure

&AtServer
Function SubgroupWithLeastNumberOfItems(Folder)
	SubgroupMin = Undefined;
	NestedItemsCountMin = 0;
	For Each Subgroup In Folder.ChildItems Do
		NestedItemsCount = Subgroup.ChildItems.Count();
		If NestedItemsCount < NestedItemsCountMin Or SubgroupMin = Undefined Then
			SubgroupMin          = Subgroup;
			NestedItemsCountMin = NestedItemsCount;
		EndIf;
	EndDo;
	Return SubgroupMin;
EndFunction

&AtServer
Procedure FillInInfoOnSubsystemsAndSetTitle()
	TitlePredefinedByCommand = Parameters.Property("Title");
	If TitlePredefinedByCommand Then
		Title = Parameters.Title;
	EndIf;
	
	If Parameters.PathToSubsystem = ReportsOptionsClientServer.HomePageID() Then
		CurrentSectionFullName = Parameters.PathToSubsystem;
	Else
		CurrentSectionFullName = "Subsystem." + StrReplace(Parameters.PathToSubsystem, ".", ".Subsystem.");
	EndIf;
	
	AllSubsystems = ReportsOptionsCached.CurrentUserSubsystems();
	AllSections = AllSubsystems.Rows[0].Rows;
	SearchForSubsystems = New Map;
	For Each RowSection In AllSections Do
		TableRow = ApplicationSubsystems.Add();
		FillPropertyValues(TableRow, RowSection);
		TableRow.ItemName    = StrReplace(RowSection.FullName, ".", "_");
		TableRow.ItemNumber  = 0;
		TableRow.SectionRef   = RowSection.Ref;
		
		SearchForSubsystems.Insert(TableRow.Ref, TableRow.GetID());
		
		If RowSection.FullName = CurrentSectionFullName Then
			CurrentSectionRef = RowSection.Ref;
			If TitlePredefinedByCommand Then
				RowSection.FullPresentation = Parameters.Title;
			Else
				Title = RowSection.FullPresentation;
			EndIf;
		EndIf;
		
		FoundItems = RowSection.Rows.FindRows(New Structure("SectionRef", RowSection.Ref), True);
		For Each TreeRow In FoundItems Do
			TableRow = ApplicationSubsystems.Add();
			FillPropertyValues(TableRow, TreeRow);
			TableRow.ItemName    = StrReplace(TableRow.FullName, ".", "_");
			TableRow.ItemNumber  = 0;
			TableRow.ParentRef = TreeRow.Parent.Ref;
			TableRow.SectionRef   = RowSection.Ref;
			
			SearchForSubsystems.Insert(TableRow.Ref, TableRow.GetID());
			If TreeRow.FullName = CurrentSectionFullName Then
				CurrentSectionRef = TreeRow.Ref;
				If TitlePredefinedByCommand Then
					TreeRow.FullPresentation = Parameters.Title;
				Else
					Title = TreeRow.FullPresentation;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
	If CurrentSectionRef = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Для панели отчетов указан несуществующий раздел ""%1"" (см. ReportOptionsOverridable.DefineSectionsWithReportOptions).'; en = 'The ""%1"" section specified for the report panel does not exist (see ReportOptionsOverridable.DefineSectionsWithReportOptions).'; pl = 'Dla panelu sprawozdań wskazano nieistniejący rozdział ""%1"" (zob. ReportOptionsOverridable.DefineSectionsWithReportOptions).';es_ES = 'Para la barra de informes se ha indicado una sección inexistente ""%1"" (véase ReportOptionsOverridable.DefineSectionsWithReportOptions).';es_CO = 'Para la barra de informes se ha indicado una sección inexistente ""%1"" (véase ReportOptionsOverridable.DefineSectionsWithReportOptions).';tr = 'Rapor paneli için var olmayan bir ""%1"" bölümü listelenir (bkz ReportOptionsOverridable.DefineSectionsWithReportOptions).';it = 'La sezione ""%1"" indicata per il pannello di report non esiste (Vedi ReportOptionsOverridable.DefineSectionsWithReportOptions).';de = 'Der Berichtsbereich enthält einen nicht vorhandenen Abschnitt ""%1"" (siehe ReportOptionsOverridable.DefineSectionsWithReportOptions).'"),
			Parameters.PathToSubsystem);
	EndIf;
	
	PurposeUseKey = "Section_" + String(CurrentSectionRef.UUID());
	QuickSearchForSubsystemsByRef = New FixedMap(SearchForSubsystems);
EndProcedure

&AtServer
Procedure ImportAllSettings()
	CommonSettings = ReportsOptions.CommonPanelSettings();
	FillPropertyValues(ThisObject, CommonSettings, "ShowTooltipsNotification, ShowTooltips, SearchInAllSections");
	
	LocalSettings = Common.CommonSettingsStorageLoad(
		ReportsOptionsClientServer.FullSubsystemName(),
		PurposeUseKey);
	If LocalSettings <> Undefined Then
		Items.SearchString.ChoiceList.LoadValues(LocalSettings.SearchStringSelectionList);
	EndIf;
EndProcedure

&AtServer
Procedure SaveSettingsOfThisReportPanel()
	LocalSettings = New Structure;
	LocalSettings.Insert("SearchStringSelectionList", Items.SearchString.ChoiceList.UnloadValues());
	
	Common.CommonSettingsStorageSave(
		ReportsOptionsClientServer.FullSubsystemName(),
		PurposeUseKey,
		LocalSettings);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server / filling in a report panel.

&AtServer
Procedure FillInReportPanel()
	// Clear information on changes in user settings.
	AddedOptions.Clear();
	
	FillingParameters = New Structure;
	InitializeFillingParameters(FillingParameters);
	
	FindReportOptionsForOutput(FillingParameters);
	
	If SetupMode Then
		FillingParameters.ContextMenu.RemoveFromQuickAccess.Visible = True;
		FillingParameters.ContextMenu.MoveToQuickAccess.Visible = False;
	EndIf;
	
	OutputSectionOptions(FillingParameters, CurrentSectionRef);
	
	If FillingParameters.CurrentSectionOnly Then
		Items.SearchResultsFromOtherSectionsGroup.Visible = False;
	Else
		Items.SearchResultsFromOtherSectionsGroup.Visible = True;
		If FillingParameters.OtherSections.Count() = 0 Then
			Label = Items.Insert("InOtherSections", Type("FormDecoration"), Items.SearchResultsFromOtherSections);
			Label.Title = "    " + NStr("ru = 'Отчеты в других разделах не найдены.'; en = 'Reports are not found in other sections.'; pl = 'Nie znaleziono raportów w innych sekcjach.';es_ES = 'Informes no se han encontrado en otras secciones.';es_CO = 'Informes no se han encontrado en otras secciones.';tr = 'Raporlar diğer bölümlerde bulunmamaktadır.';it = 'Report non trovati in altre sezioni.';de = 'Berichte werden in anderen Abschnitten nicht gefunden.'") + Chars.LF;
			Label.Height = 2;
		EndIf;
		For Each SectionRef In FillingParameters.OtherSections Do
			OutputSectionOptions(FillingParameters, SectionRef);
		EndDo;
		If FillingParameters.NotDisplayed > 0 Then // Display information label.
			LabelTitle = NStr("ru = 'Выведены первые %1 отчетов из других разделов, уточните поисковый запрос.'; en = 'The first %1 reports from other sections are shown. Please refine the search.'; pl = 'Wyświetlane są%1pierwsze sprawozdania z innych sekcji, uściślij zapytanie.';es_ES = 'Primeros %1 informes de otras secciones están visualizados, especificar la solicitud de búsqueda.';es_CO = 'Primeros %1 informes de otras secciones están visualizados, especificar la solicitud de búsqueda.';tr = 'Diğer bölümlerden ilk %1 raporlar görüntülenir, bir arama sorgusu belirtin.';it = 'I primi report %1 da altre sezioni sono mostrati. Si prega di rifinire la ricerca.';de = 'Die ersten %1 Berichte aus anderen Abschnitten werden angezeigt, geben Sie eine Suchanfrage an.'");
			LabelTitle = StringFunctionsClientServer.SubstituteParametersToString(LabelTitle, FillingParameters.OutputLimit);
			Label = Items.Insert("OutputLimitExceeded", Type("FormDecoration"), Items.SearchResultsFromOtherSections);
			Label.Title = LabelTitle;
			Label.Font = ImportantLabelFont;
			Label.Height = 2;
		EndIf;
	EndIf;
	
	If FillingParameters.AttributesToAdd.Count() > 0 Then
		// Register old attributes for deleting.
		AttributesToDelete = New Array;
		SetOfAttributes = GetAttributes();
		For Each Attribute In SetOfAttributes Do
			If ConstantAttributes.FindByValue(Attribute.Name) = Undefined Then
				AttributesToDelete.Add(Attribute.Name);
			EndIf;
		EndDo;
		// Delete old attributes and add new ones.
		ChangeAttributes(FillingParameters.AttributesToAdd, AttributesToDelete);
		// Link new attributes to data.
		For Each Attribute In FillingParameters.AttributesToAdd Do
			CheckBox = Items.Find(Attribute.Name);
			CheckBox.DataPath = Attribute.Name;
			LabelName = Mid(Attribute.Name, StrLen("CheckBox_")+1);
			FoundItems = AddedOptions.FindRows(New Structure("LabelName", LabelName));
			If FoundItems.Count() > 0 Then
				Option = FoundItems[0];
				ThisObject[Attribute.Name] = Option.Visible;
			EndIf;
		EndDo;
	EndIf;
	
	QuickSearchForOptionsByItemName = New FixedMap(FillingParameters.SearchForOptions);
EndProcedure

&AtServer
Procedure InitializeFillingParameters(FillingParameters)
	FillingParameters.Insert("NameOfGroup", "");
	FillingParameters.Insert("AttributesToAdd", New Array);
	FillingParameters.Insert("EmptyDecorationsAdded", 0);
	FillingParameters.Insert("OutputLimit", 20);
	FillingParameters.Insert("RemainsToOutput", FillingParameters.OutputLimit);
	FillingParameters.Insert("NotDisplayed", 0);
	FillingParameters.Insert("OptionItemsDisplayed", 0);
	FillingParameters.Insert("SearchForOptions", New Map);
	
	OptionGroupTemplate = New Structure(
		"Kind, HorizontalStretch,
		|Representation, Group, 
		|ShowTitle");
	OptionGroupTemplate.Kind = FormGroupType.UsualGroup;
	OptionGroupTemplate.HorizontalStretch = True;
	OptionGroupTemplate.Representation = UsualGroupRepresentation.None;
	OptionGroupTemplate.Group = ChildFormItemsGroup.AlwaysHorizontal;
	OptionGroupTemplate.ShowTitle = False;
	
	QuickAccessPictureTemplate = New Structure(
		"Kind, Width, Height, Picture,
		|HorizontalStretch, VerticalStretch");
	QuickAccessPictureTemplate.Kind = FormDecorationType.Picture;
	QuickAccessPictureTemplate.Width = 2;
	QuickAccessPictureTemplate.Height = 1;
	QuickAccessPictureTemplate.Picture = QuickAccessPicture;
	QuickAccessPictureTemplate.HorizontalStretch = False;
	QuickAccessPictureTemplate.VerticalStretch = False;
	
	IndentPictureTemplate = New Structure(
		"Kind, Width, Height,
		|HorizontalStretch, VerticalStretch");
	IndentPictureTemplate.Kind = FormDecorationType.Picture;
	IndentPictureTemplate.Width = 1;
	IndentPictureTemplate.Height = 1;
	IndentPictureTemplate.HorizontalStretch = False;
	IndentPictureTemplate.VerticalStretch = False;
	
	// Templates for filling in control items to be created.
	OptionLabelTemplate = New Structure(
		"Kind, Hyperlink, TextColor,
		|VerticalStretch, Height,
		|HorizontalStretch, AutoMaxWidth, MaxWidth");
	OptionLabelTemplate.Kind = FormDecorationType.Label;
	OptionLabelTemplate.Hyperlink = True;
	OptionLabelTemplate.TextColor = VisibleOptionsColor;
	OptionLabelTemplate.VerticalStretch = False;
	OptionLabelTemplate.Height = 1;
	OptionLabelTemplate.HorizontalStretch = True;
	OptionLabelTemplate.AutoMaxWidth = False;
	OptionLabelTemplate.MaxWidth = 0;
	
	FillingParameters.Insert("Templates", New Structure);
	FillingParameters.Templates.Insert("OptionGroup", OptionGroupTemplate);
	FillingParameters.Templates.Insert("QuickAccessPicture", QuickAccessPictureTemplate);
	FillingParameters.Templates.Insert("IndentPicture", IndentPictureTemplate);
	FillingParameters.Templates.Insert("OptionLabel", OptionLabelTemplate);
	
	If SetupMode Then
		FillingParameters.Insert("ContextMenu", New Structure("RemoveFromQuickAccess, MoveToQuickAccess, Change"));
		FillingParameters.ContextMenu.RemoveFromQuickAccess   = New Structure("Visible", False);
		FillingParameters.ContextMenu.MoveToQuickAccess = New Structure("Visible", False);
		FillingParameters.ContextMenu.Change                  = New Structure("Visible", True);
	EndIf;
	
	FillingParameters.Insert("ImportanceGroups", New Array);
	FillingParameters.ImportanceGroups.Add("QuickAccess");
	FillingParameters.ImportanceGroups.Add("NoGroup");
	FillingParameters.ImportanceGroups.Add("WithGroup");
	FillingParameters.ImportanceGroups.Add("SeeAlso");
	
	For Each NameOfGroup In FillingParameters.ImportanceGroups Do
		FillingParameters.Insert(NameOfGroup, New Structure("Filter, Variants, Count"));
	EndDo;
	
	FillingParameters.QuickAccess.Filter = New Structure("QuickAccess", True);
	FillingParameters.NoGroup.Filter     = New Structure("QuickAccess, NoGroup", False, True);
	FillingParameters.WithGroup.Filter      = New Structure("QuickAccess, NoGroup, SeeAlso", False, False, False);
	FillingParameters.SeeAlso.Filter       = New Structure("QuickAccess, NoGroup, SeeAlso", False, False, True);
	
EndProcedure

&AtServer
Procedure FindReportOptionsForOutput(FillingParameters)
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	Subsystems.Ref AS Subsystem,
	|	Subsystems.SectionRef AS SectionRef,
	|	Subsystems.Presentation AS Presentation,
	|	Subsystems.Priority AS Priority
	|INTO ttSubsystems
	|FROM
	|	&SubsystemsTable AS Subsystems
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReportsOptions.Ref AS Ref,
	|	PredefinedPlacement.Subsystem AS Subsystem,
	|	PredefinedPlacement.Important AS Important,
	|	PredefinedPlacement.SeeAlso AS SeeAlso,
	|	CASE
	|		WHEN SUBSTRING(ReportsOptions.Details, 1, 1) = """"
	|			THEN CAST(PredefinedPlacement.Ref.Details AS STRING(1000))
	|		ELSE CAST(ReportsOptions.Details AS STRING(1000))
	|	END AS Details,
	|	ReportsOptions.Description AS Description,
	|	ReportsOptions.Report AS Report,
	|	ReportsOptions.ReportType AS ReportType,
	|	ReportsOptions.VariantKey AS VariantKey,
	|	ReportsOptions.Author AS Author,
	|	CASE
	|		WHEN ReportsOptions.DefaultVisibilityOverridden
	|			THEN ReportsOptions.VisibleByDefault
	|		ELSE PredefinedPlacement.Ref.VisibleByDefault
	|	END AS VisibleByDefault,
	|	ReportsOptions.Parent AS Parent,
	|	ReportsOptions.PredefinedVariant.MeasurementsKey AS MeasurementsKey
	|INTO ttPredefined
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|		INNER JOIN Catalog.PredefinedReportsOptions.Placement AS PredefinedPlacement
	|		ON (ReportsOptions.Ref IN (&OptionsFoundBySearch)
	|				OR PredefinedPlacement.Subsystem IN (&SubsystemsFoundBySearch))
	|			AND ReportsOptions.PredefinedVariant = PredefinedPlacement.Ref
	|			AND (PredefinedPlacement.Subsystem IN (&SubsystemsArray))
	|			AND (ReportsOptions.DeletionMark = FALSE)
	|			AND (ReportsOptions.Report IN (&UserReports))
	|			AND (NOT PredefinedPlacement.Ref IN (&DIsabledApplicationOptions))
	|
	|UNION ALL
	|
	|SELECT
	|	ReportsOptions.Ref,
	|	PredefinedPlacement.Subsystem,
	|	PredefinedPlacement.Important,
	|	PredefinedPlacement.SeeAlso,
	|	CASE
	|		WHEN SUBSTRING(ReportsOptions.Details, 1, 1) = """"
	|			THEN CAST(PredefinedPlacement.Ref.Details AS STRING(1000))
	|		ELSE CAST(ReportsOptions.Details AS STRING(1000))
	|	END,
	|	ReportsOptions.Description,
	|	ReportsOptions.Report,
	|	ReportsOptions.ReportType,
	|	ReportsOptions.VariantKey,
	|	ReportsOptions.Author,
	|	CASE
	|		WHEN ReportsOptions.DefaultVisibilityOverridden
	|			THEN ReportsOptions.VisibleByDefault
	|		ELSE PredefinedPlacement.Ref.VisibleByDefault
	|	END,
	|	ReportsOptions.Parent,
	|	ReportsOptions.PredefinedVariant.MeasurementsKey
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|		INNER JOIN Catalog.PredefinedExtensionsReportsOptions.Placement AS PredefinedPlacement
	|		ON (ReportsOptions.Ref IN (&OptionsFoundBySearch)
	|				OR PredefinedPlacement.Subsystem IN (&SubsystemsFoundBySearch))
	|			AND ReportsOptions.PredefinedVariant = PredefinedPlacement.Ref
	|			AND (PredefinedPlacement.Subsystem IN (&SubsystemsArray))
	|			AND (ReportsOptions.Report IN (&UserReports))
	|			AND (NOT PredefinedPlacement.Ref IN (&DIsabledApplicationOptions))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OptionsPlacement.Ref AS Ref,
	|	OptionsPlacement.Subsystem AS Subsystem,
	|	OptionsPlacement.Use AS Use,
	|	OptionsPlacement.Important AS Important,
	|	OptionsPlacement.SeeAlso AS SeeAlso,
	|	CASE
	|		WHEN SUBSTRING(OptionsPlacement.Ref.Details, 1, 1) = """"
	|				AND NOT OptionsPlacement.Ref.Custom
	|			THEN CAST(OptionsPlacement.Ref.PredefinedVariant.Details AS STRING(1000))
	|		ELSE CAST(OptionsPlacement.Ref.Details AS STRING(1000))
	|	END AS Details,
	|	OptionsPlacement.Ref.AvailableToAuthorOnly AS AvailableToAuthorOnly,
	|	OptionsPlacement.Ref.Description AS Description,
	|	OptionsPlacement.Ref.Report AS Report,
	|	OptionsPlacement.Ref.ReportType AS ReportType,
	|	OptionsPlacement.Ref.VariantKey AS VariantKey,
	|	OptionsPlacement.Ref.Author AS Author,
	|	CASE
	|		WHEN OptionsPlacement.Ref.Parent = VALUE(Catalog.ReportsOptions.EmptyRef)
	|			THEN VALUE(Catalog.ReportsOptions.EmptyRef)
	|		WHEN OptionsPlacement.Ref.Parent.Parent = VALUE(Catalog.ReportsOptions.EmptyRef)
	|			THEN OptionsPlacement.Ref.Parent
	|		ELSE OptionsPlacement.Ref.Parent.Parent
	|	END AS Parent,
	|	OptionsPlacement.Ref.VisibleByDefault AS VisibleByDefault,
	|	OptionsPlacement.Ref.PredefinedVariant.MeasurementsKey AS MeasurementsKey
	|INTO ttOptions
	|FROM
	|	Catalog.ReportsOptions.Placement AS OptionsPlacement
	|WHERE
	|	(OptionsPlacement.Ref IN (&OptionsFoundBySearch)
	|			OR OptionsPlacement.Subsystem IN (&SubsystemsFoundBySearch))
	|	AND (NOT OptionsPlacement.Ref.AvailableToAuthorOnly
	|			OR OptionsPlacement.Ref.Author = &CurrentUser)
	|	AND OptionsPlacement.Subsystem IN(&SubsystemsArray)
	|	AND OptionsPlacement.Ref.Report IN(&UserReports)
	|	AND NOT OptionsPlacement.Ref.PredefinedVariant IN (&DIsabledApplicationOptions)
	|	AND (NOT OptionsPlacement.Ref.Custom
	|			OR NOT OptionsPlacement.Ref.InteractiveSetDeletionMark)
	|	AND (OptionsPlacement.Ref.Custom
	|			OR NOT OptionsPlacement.Ref.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ISNULL(ttOptions.Ref, ttPredefined.Ref) AS Ref,
	|	ISNULL(ttOptions.Subsystem, ttPredefined.Subsystem) AS Subsystem,
	|	ISNULL(ttOptions.Important, ttPredefined.Important) AS Important,
	|	ISNULL(ttOptions.SeeAlso, ttPredefined.SeeAlso) AS SeeAlso,
	|	ISNULL(ttOptions.Description, ttPredefined.Description) AS Description,
	|	ISNULL(ttOptions.Details, ttPredefined.Details) AS Details,
	|	ISNULL(ttOptions.Author, ttPredefined.Author) AS Author,
	|	ISNULL(ttOptions.Report, ttPredefined.Report) AS Report,
	|	ISNULL(ttOptions.ReportType, ttPredefined.ReportType) AS ReportType,
	|	ISNULL(ttOptions.VariantKey, ttPredefined.VariantKey) AS VariantKey,
	|	ISNULL(ttOptions.VisibleByDefault, ttPredefined.VisibleByDefault) AS VisibleByDefault,
	|	ISNULL(ttOptions.Parent, ttPredefined.Parent) AS Parent,
	|	CASE
	|		WHEN ISNULL(ttOptions.Parent, ttPredefined.Parent) = VALUE(Catalog.ReportsOptions.EmptyRef)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS TopLevel,
	|	ISNULL(ttOptions.MeasurementsKey, ttPredefined.MeasurementsKey) AS MeasurementsKey
	|INTO ttAllOptions
	|FROM
	|	ttPredefined AS ttPredefined
	|		FULL JOIN ttOptions AS ttOptions
	|		ON ttPredefined.Ref = ttOptions.Ref
	|			AND ttPredefined.Subsystem = ttOptions.Subsystem
	|WHERE
	|	ISNULL(ttOptions.Use, TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ttAllOptions.Ref AS Ref,
	|	ttAllOptions.Subsystem AS Subsystem,
	|	ttSubsystems.Presentation AS SubsystemPresentation,
	|	ttSubsystems.Priority AS SubsystemPriority,
	|	ttSubsystems.SectionRef AS SectionRef,
	|	CASE
	|		WHEN ttAllOptions.Subsystem = ttSubsystems.SectionRef
	|				AND ttAllOptions.SeeAlso = FALSE
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS NoGroup,
	|	ttAllOptions.Important AS Important,
	|	ttAllOptions.SeeAlso AS SeeAlso,
	|	CASE
	|		WHEN ttAllOptions.ReportType = &AdditionalType
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS Additional,
	|	ISNULL(PersonalSettings.Visible, ttAllOptions.VisibleByDefault) AS Visible,
	|	ISNULL(PersonalSettings.QuickAccess, FALSE) AS QuickAccess,
	|	CASE
	|		WHEN ttAllOptions.ReportType = &InternalType
	|				OR ttAllOptions.ReportType = &ExtensionType
	|			THEN ttAllOptions.Report.Name
	|		WHEN ttAllOptions.ReportType = &AdditionalType
	|			THEN """"
	|		ELSE SUBSTRING(CAST(ttAllOptions.Report AS STRING(150)), 14, 137)
	|	END AS ReportName,
	|	ttAllOptions.Description AS Description,
	|	ttAllOptions.Details AS Details,
	|	ttAllOptions.Author AS Author,
	|	ttAllOptions.Report AS Report,
	|	ttAllOptions.ReportType AS ReportType,
	|	ttAllOptions.VariantKey AS VariantKey,
	|	ttAllOptions.Parent AS Parent,
	|	ttAllOptions.TopLevel AS TopLevel,
	|	ttAllOptions.MeasurementsKey AS MeasurementsKey
	|FROM
	|	ttAllOptions AS ttAllOptions
	|		LEFT JOIN ttSubsystems AS ttSubsystems
	|		ON ttAllOptions.Subsystem = ttSubsystems.Subsystem
	|		LEFT JOIN InformationRegister.ReportOptionsSettings AS PersonalSettings
	|		ON ttAllOptions.Subsystem = PersonalSettings.Subsystem
	|			AND ttAllOptions.Ref = PersonalSettings.Variant
	|			AND (PersonalSettings.User = &CurrentUser)
	|WHERE
	|	ISNULL(PersonalSettings.Visible, ttAllOptions.VisibleByDefault)
	|
	|ORDER BY
	|	SubsystemPriority,
	|	Description";
	
	CurrentSectionOnly = SetupMode Or Not ValueIsFilled(SearchString) Or SearchInAllSections = 0;
	If CurrentSectionOnly Then
		SubsystemsTable = ApplicationSubsystems.Unload(New Structure("SectionRef", CurrentSectionRef));
	Else
		SubsystemsTable = ApplicationSubsystems.Unload();
	EndIf;
	SubsystemsTable.Indexes.Add("Ref");
	SubsystemsArray = SubsystemsTable.UnloadColumn("Ref");
	
	UseHighlighting = ValueIsFilled(SearchString);
	
	SearchParameters = New Structure;
	If UseHighlighting Then
		SearchParameters.Insert("SearchString", SearchString);
	EndIf;
	If CurrentSectionOnly Then
		SearchParameters.Insert("Subsystems", SubsystemsArray);
	EndIf;
	
	SearchResult = ReportsOptions.FindLinks(SearchParameters);
	
	If UsersClientServer.IsExternalUserSession() Then
		Query.SetParameter("CurrentUser", UsersClientServer.CurrentExternalUser());
	Else
		Query.SetParameter("CurrentUser", Users.AuthorizedUser());
	EndIf;
	
	Query.SetParameter("SubsystemsArray",      SubsystemsArray);
	Query.SetParameter("SubsystemsTable",     SubsystemsTable);
	Query.SetParameter("SectionRef",         CurrentSectionRef);
	Query.SetParameter("InternalType",        Enums.ReportTypes.Internal);
	Query.SetParameter("ExtensionType",        Enums.ReportTypes.Extension);
	Query.SetParameter("AdditionalType",    Enums.ReportTypes.Additional);
	Query.SetParameter("OptionsFoundBySearch", SearchResult.References);
	If UseHighlighting AND SearchResult.Subsystems.Count() > 0 Then
		Query.SetParameter("SubsystemsFoundBySearch",   SearchResult.Subsystems);
		Query.SetParameter("UserReports",           SearchParameters.UserReports);
		Query.SetParameter("DIsabledApplicationOptions", SearchParameters.DIsabledApplicationOptions);
	Else
		Query.Text = StrReplace(
			Query.Text,
			"(ReportsOptions.Ref IN (&OptionsFoundBySearch)
			|				OR PredefinedPlacement.Subsystem IN (&SubsystemsFoundBySearch))",
			"(ReportsOptions.Ref IN (&OptionsFoundBySearch))");
		Query.Text = StrReplace(
			Query.Text,
			"(OptionsPlacement.Ref IN (&OptionsFoundBySearch)
			|			OR OptionsPlacement.Subsystem IN (&SubsystemsFoundBySearch))",
			"OptionsPlacement.Ref IN (&OptionsFoundBySearch)");
		Query.Text = StrReplace(
			Query.Text,
			"
			|			AND (ReportsOptions.Report IN (&UserReports))
			|			AND (NOT PredefinedPlacement.Ref IN (&DIsabledApplicationOptions))",
			"");
		Query.Text = StrReplace(
			Query.Text,
			"
			|	AND OptionsPlacement.Ref.Report IN(&UserReports)
			|	AND NOT OptionsPlacement.Ref.PredefinedVariant IN (&DIsabledApplicationOptions)",
			"");
	EndIf;
	
	If SetupMode Or UseHighlighting Then
		FragmentToDelete = 
			"WHERE
			|	ISNULL(PersonalSettings.Visible, ttAllOptions.VisibleByDefault)";
		Query.Text = StrReplace(Query.Text, FragmentToDelete, "");
	EndIf;
	
	Query.TempTablesManager = New TempTablesManager;
	ResultTable = Query.Execute().Unload();
	ResultTable.Columns.Add("OutputWithMainReport", New TypeDescription("Boolean"));
	ResultTable.Columns.Add("SubordinateCount", New TypeDescription("Number"));
	ResultTable.Indexes.Add("Ref");
	
	ReportsIDs = New Array;
	For Each ReportRow In ResultTable Do
		If Not ReportRow.Additional Then
			ReportsIDs.Add(ReportRow.Report);
		EndIf;
	EndDo;
	
	ReportsObjects = Catalogs.MetadataObjectIDs.MetadataObjectsByIDs(ReportsIDs);
	For Each ReportForOutput In ResultTable Do
		If ReportForOutput.ReportType = Enums.ReportTypes.Internal
			Or ReportForOutput.ReportType = Enums.ReportTypes.Extension Then
				MetadataOfReport = ReportsObjects[ReportForOutput.Report];
				If ReportForOutput.ReportName <> MetadataOfReport.Name Then
					ReportForOutput.ReportName = MetadataOfReport.Name;
				EndIf;
		EndIf;
	EndDo;
	
	If UseHighlighting Then
		// Delete records about options that are linked to subsystems if a record is not mentioned in the link.
		For Each KeyAndValue In SearchResult.OptionsLinkedWithSubsystems Do
			OptionRef = KeyAndValue.Key;
			LinkedSubsystems = KeyAndValue.Value;
			FoundItems = ResultTable.FindRows(New Structure("Ref", OptionRef));
			For Each TableRow In FoundItems Do
				If LinkedSubsystems.Find(TableRow.Subsystem) = Undefined Then
					ResultTable.Delete(TableRow);
				EndIf;
			EndDo;
		EndDo;
		// Delete records about parents that are linked to options if a parent attempts to output without options.
		For Each ParentRef In SearchResult.ParentsLinkedWithOptions Do
			OutputLocation = ResultTable.FindRows(New Structure("Ref", ParentRef));
			For Each TableRow In OutputLocation Do
				FoundItems = ResultTable.FindRows(New Structure("Subsystem, Parent", TableRow.Subsystem, ParentRef));
				If FoundItems.Count() = 0 Then
					ResultTable.Delete(TableRow);
				EndIf;
			EndDo;
		EndDo;
	EndIf;
	
	If CurrentSectionOnly Then
		OtherSections = New Array;
	Else
		TableCopy = ResultTable.Copy();
		TableCopy.GroupBy("SectionRef");
		OtherSections = TableCopy.UnloadColumn("SectionRef");
		Index = OtherSections.Find(CurrentSectionRef);
		If Index <> Undefined Then
			OtherSections.Delete(Index);
		EndIf;
	EndIf;
	
	If UseHighlighting Then
		WordArray = ReportsOptionsClientServer.ParseSearchStringIntoWordArray(Upper(TrimAll(SearchString)));
	Else
		WordArray = Undefined;
	EndIf;
	
	FillingParameters.Insert("CurrentSectionOnly", CurrentSectionOnly);
	FillingParameters.Insert("SubsystemsTable", SubsystemsTable);
	FillingParameters.Insert("OtherSections", OtherSections);
	FillingParameters.Insert("Variants", ResultTable);
	FillingParameters.Insert("UseHighlighting", ValueIsFilled(SearchString));
	FillingParameters.Insert("SearchResult", SearchResult);
	FillingParameters.Insert("WordArray", WordArray);
EndProcedure

&AtServer
Procedure OutputSectionOptions(FillingParameters, SectionRef)
	FilterBySection = New Structure("SectionRef", SectionRef);
	SectionOptions = FillingParameters.Variants.Copy(FilterBySection);
	FillingParameters.Insert("CurrentSectionOptionsDisplayed", SectionRef = CurrentSectionRef);
	FillingParameters.Insert("SectionOptions",    SectionOptions);
	FillingParameters.Insert("OptionsNumber", SectionOptions.Count());
	If FillingParameters.OptionsNumber = 0 Then
		// Displays a text explaining the absence of options (for the current section only).
		If FillingParameters.CurrentSectionOptionsDisplayed Then
			Label = Items.Insert("ReportListEmpty", Type("FormDecoration"), Items.NoGroupColumn1);
			If ValueIsFilled(SearchString) Then
				If FillingParameters.CurrentSectionOnly Then
					Label.Title = NStr("ru = 'Отчеты не найдены.'; en = 'Reports not found.'; pl = 'Nie znaleziono raportów.';es_ES = 'Informes no encontrados.';es_CO = 'Informes no encontrados.';tr = 'Raporlar bulunamadı.';it = 'Report non trovati.';de = 'Berichte nicht gefunden.'");
				Else
					Label.Title = NStr("ru = 'Отчеты в текущем разделе не найдены.'; en = 'Reports are not found in the current section.'; pl = 'Nie znaleziono sprawozdań w bieżącej sekcji.';es_ES = 'Informes no encontrados en la sección actual.';es_CO = 'Informes no encontrados en la sección actual.';tr = 'Mevcut bölümde raporlar bulunamadı.';it = 'Report non trovati nella sezione corrente.';de = 'Berichte werden im aktuellen Abschnitt nicht gefunden.'");
					Label.Height = 2;
				EndIf;
			Else
				Label.Title = NStr("ru = 'В панели отчетов этого раздела не размещено ни одного отчета.'; en = 'Report panel of this section does not contain any reports.'; pl = 'Panel sprawozdań w tej sekcji nie zawiera żadnych sprawozdań.';es_ES = 'Panel de informes de esta sección no contiene ningún informe.';es_CO = 'Panel de informes de esta sección no contiene ningún informe.';tr = 'Bu bölümün rapor paneli herhangi bir rapor içermiyor.';it = 'Non ci sono segnalazioni nel pannello dei report di questa sezione.';de = 'Der Berichtspaneel dieses Abschnitts enthält keine Berichte.'");
			EndIf;
			Items["QuickAccessHeader"].Visible  = False;
			Items["QuickAccessFooter"].Visible = False;
			Items["NoGroupFooter"].Visible     = False;
			Items["WithGroupFooter"].Visible      = False;
			Items["SeeAlsoHeader"].Visible    = False;
			Items["SeeAlsoFooter"].Visible       = False;
			Items.QuickAccessTooltipWhenNotConfigured.Visible = False;
		EndIf;
		Return;
	EndIf;
	
	If FillingParameters.CurrentSectionOnly Then
		SectionSubsystems = FillingParameters.SubsystemsTable;
	Else
		SectionSubsystems = FillingParameters.SubsystemsTable.Copy(FilterBySection);
	EndIf;
	SectionSubsystems.Sort("Priority ASC"); // Sort by the hierarchy
	
	FillingParameters.Insert("SectionRef",      SectionRef);
	FillingParameters.Insert("SectionSubsystems", SectionSubsystems);
	
	DefineGroupsAndDecorationsToDisplayOptions(FillingParameters);
	
	If Not FillingParameters.CurrentSectionOptionsDisplayed
		AND FillingParameters.RemainsToOutput = 0 Then
		FillingParameters.NotDisplayed = FillingParameters.NotDisplayed + FillingParameters.OptionsNumber;
		Return;
	EndIf;
	
	For Each NameOfGroup In FillingParameters.ImportanceGroups Do
		GroupParameters = FillingParameters[NameOfGroup];
		If FillingParameters.RemainsToOutput <= 0 Then
			GroupParameters.Variants   = New Array;
			GroupParameters.Count = 0;
		Else
			GroupParameters.Variants   = FillingParameters.SectionOptions.Copy(GroupParameters.Filter);
			GroupParameters.Count = GroupParameters.Variants.Count();
		EndIf;
		
		If GroupParameters.Count = 0 AND Not (SetupMode AND NameOfGroup = "WithGroup") Then
			Continue;
		EndIf;
		
		If Not FillingParameters.CurrentSectionOptionsDisplayed Then
			// Restriction for options output.
			FillingParameters.RemainsToOutput = FillingParameters.RemainsToOutput - GroupParameters.Count;
			If FillingParameters.RemainsToOutput < 0 Then
				// Remove rows that exceed the limit.
				ExcessiveOptions = -FillingParameters.RemainsToOutput;
				For Number = 1 To ExcessiveOptions Do
					GroupParameters.Variants.Delete(GroupParameters.Count - Number);
				EndDo;
				FillingParameters.NotDisplayed = FillingParameters.NotDisplayed + ExcessiveOptions;
				FillingParameters.RemainsToOutput = 0;
			EndIf;
		EndIf;
		
		If SetupMode Then
			FillingParameters.ContextMenu.RemoveFromQuickAccess.Visible   = (NameOfGroup = "QuickAccess");
			FillingParameters.ContextMenu.MoveToQuickAccess.Visible = (NameOfGroup <> "QuickAccess");
		EndIf;
		
		FillingParameters.NameOfGroup = NameOfGroup;
		OutputOptionsWithGroup(FillingParameters);
	EndDo;
	
	HasQuickAccess     = (FillingParameters.QuickAccess.Count > 0);
	HasOptionsWithoutGroups = (FillingParameters.NoGroup.Count > 0);
	HasOptionsWithGroups  = (FillingParameters.WithGroup.Count > 0);
	HasOptionsSeeAlso   = (FillingParameters.SeeAlso.Count > 0);
	
	Items[FillingParameters.Prefix + "QuickAccessHeader"].Visible  = SetupMode Or HasQuickAccess;
	Items[FillingParameters.Prefix + "QuickAccessFooter"].Visible = (
		SetupMode
		Or (
			HasQuickAccess
			AND (
				HasOptionsWithoutGroups
				Or HasOptionsWithGroups
				Or HasOptionsSeeAlso)));
	Items[FillingParameters.Prefix + "NoGroupFooter"].Visible  = HasOptionsWithoutGroups;
	Items[FillingParameters.Prefix + "WithGroupFooter"].Visible   = HasOptionsWithGroups;
	Items[FillingParameters.Prefix + "SeeAlsoHeader"].Visible = HasOptionsSeeAlso;
	Items[FillingParameters.Prefix + "SeeAlsoFooter"].Visible    = HasOptionsSeeAlso;
	
	If FillingParameters.CurrentSectionOptionsDisplayed Then
		Items.QuickAccessTooltipWhenNotConfigured.Visible = SetupMode AND Not HasQuickAccess;
	EndIf;
	
EndProcedure

&AtServer
Procedure DefineGroupsAndDecorationsToDisplayOptions(FillingParameters)
	// This procedure defines the substitution of standard groups and items.
	FillingParameters.Insert("Prefix", "");
	If FillingParameters.CurrentSectionOptionsDisplayed Then
		Return;
	EndIf;
	
	InformationOnSection = FillingParameters.SubsystemsTable.Find(FillingParameters.SectionRef, "Ref");
	FillingParameters.Prefix = "Section_" + InformationOnSection.Priority + "_";
	
	SectionGroupName = FillingParameters.Prefix + InformationOnSection.Name;
	SectionGroup = Items.Insert(SectionGroupName, Type("FormGroup"), Items.SearchResultsFromOtherSections);
	SectionGroup.Type         = FormGroupType.UsualGroup;
	SectionGroup.Representation = UsualGroupRepresentation.None;
	SectionGroup.ShowTitle      = False;
	SectionGroup.ToolTipRepresentation     = ToolTipRepresentation.ShowTop;
	SectionGroup.HorizontalStretch = True;
	
	SectionSuffix = " (" + Format(FillingParameters.OptionsNumber, "NZ=0; NG=") + ")" + Chars.LF;
	If FillingParameters.UseHighlighting Then
		HighlightingParameters = FillingParameters.SearchResult.SubsystemsHighlight.Get(FillingParameters.SectionRef);
		If HighlightingParameters = Undefined Then
			PresentationHighlighting = New Structure("Value, FoundWordsCount, WordHighlighting", InformationOnSection.Presentation, 0, New ValueList);
			For Each Word In FillingParameters.WordArray Do
				ReportsOptions.MarkWord(PresentationHighlighting, Word);
			EndDo;
		Else
			PresentationHighlighting = HighlightingParameters.SubsystemDescription;
		EndIf;
		PresentationHighlighting.Value = PresentationHighlighting.Value + SectionSuffix;
		If PresentationHighlighting.FoundWordsCount > 0 Then
			TitleOfSection = GenerateRowWithHighlighting(PresentationHighlighting);
		Else
			TitleOfSection = PresentationHighlighting.Value;
		EndIf;
	Else
		TitleOfSection = InformationOnSection.Presentation + SectionSuffix;
	EndIf;
	
	SectionTitle = SectionGroup.ExtendedTooltip;
	SectionTitle.Title   = TitleOfSection;
	SectionTitle.Font       = SectionFont;
	SectionTitle.TextColor  = SectionColor;
	SectionTitle.Height      = 2;
	SectionTitle.Hyperlink = True;
	SectionTitle.VerticalAlign = ItemVerticalAlign.Top;
	SectionTitle.HorizontalStretch = True;
	SectionTitle.SetAction("Click", "Attachable_SectionTitleClick");
	
	SectionGroup.Group = ChildFormItemsGroup.AlwaysHorizontal;
	
	IndentDecorationName = FillingParameters.Prefix + "IndentDecoration";
	IndentDecoration = Items.Insert(IndentDecorationName, Type("FormDecoration"), SectionGroup);
	IndentDecoration.Type = FormDecorationType.Label;
	IndentDecoration.Title = " ";
	
	// Previously an output limit was reached in other groups, so there is no need to generate subordinate objects.
	If FillingParameters.RemainsToOutput = 0 Then
		SectionTitle.Height = 1; // You do not have to separate the section title from options any more.
		Return;
	EndIf;
	
	CopyItem(FillingParameters.Prefix, SectionGroup, "Columns", 2);
	
	Items.Delete(Items[FillingParameters.Prefix + "QuickAccessTooltipWhenNotConfigured"]);
	Items[FillingParameters.Prefix + "QuickAccessHeader"].ExtendedTooltip.Title = "";
EndProcedure

&AtServer
Function CopyItem(NewItemPrefix, NewItemGroup, ItemToCopyName, NestingLevel)
	ItemToCopy = Items.Find(ItemToCopyName);
	NewItemName = NewItemPrefix + ItemToCopyName;
	NewItem = Items.Find(NewItemName);
	ItemType = TypeOf(ItemToCopy);
	IsFolder = (ItemType = Type("FormGroup"));
	If NewItem = Undefined Then
		NewItem = Items.Insert(NewItemName, ItemType, NewItemGroup);
	EndIf;
	If IsFolder Then
		PropertiesNotToFill = "Name, Parent, Visible, Shortcut, ChildItems, TitleDataPath";
	Else
		PropertiesNotToFill = "Name, Parent, Visible, Shortcut, ExtendedToolTip";
	EndIf;
	FillPropertyValues(NewItem, ItemToCopy, , PropertiesNotToFill);
	If IsFolder AND NestingLevel > 0 Then
		For Each SubordinateItem In ItemToCopy.ChildItems Do
			CopyItem(NewItemPrefix, NewItem, SubordinateItem.Name, NestingLevel - 1);
		EndDo;
	EndIf;
	Return NewItem;
EndFunction

&AtServer
Procedure OutputOptionsWithGroup(FillingParameters)
	GroupParameters = FillingParameters[FillingParameters.NameOfGroup];
	Options = GroupParameters.Variants;
	OptionsCount = GroupParameters.Count;
	If OptionsCount = 0 AND Not (SetupMode AND FillingParameters.NameOfGroup = "WithGroup") Then
		Return;
	EndIf;
	
	// Basic properties of the level 2 group.
	Level2GroupName = FillingParameters.NameOfGroup;
	Level2Group = Items.Find(FillingParameters.Prefix + Level2GroupName);
	
	DisplayWithoutGroups = (Level2GroupName = "QuickAccess" Or Level2GroupName = "SeeAlso");
	
	// Sort options (there are groups and important objects).
	Options.Sort("SubsystemPriority ASC, Important DESC, Description ASC");
	ParentsFound = Options.FindRows(New Structure("TopLevel", True));
	For Each ParentOption In ParentsFound Do
		SubordinateObjectsFound = Options.FindRows(New Structure("Parent, Subsystem", ParentOption.Ref, ParentOption.Subsystem));
		CurrentIndex = Options.IndexOf(ParentOption);
		For Each SubordinateObjectOption In SubordinateObjectsFound Do
			ParentOption.SubordinateCount = ParentOption.SubordinateCount + 1;
			SubordinateObjectOption.OutputWithMainReport = True;
			SubordinateObjectIndex = Options.IndexOf(SubordinateObjectOption);
			If SubordinateObjectIndex < CurrentIndex Then
				Options.Move(SubordinateObjectIndex, CurrentIndex - SubordinateObjectIndex);
			ElsIf SubordinateObjectIndex = CurrentIndex Then
				CurrentIndex = CurrentIndex + 1;
			Else
				Options.Move(SubordinateObjectIndex, CurrentIndex - SubordinateObjectIndex + 1);
				CurrentIndex = CurrentIndex + 1;
			EndIf;
		EndDo;
	EndDo;
	
	IDTypesDetails = New TypeDescription;
	IDTypesDetails.Types().Add("CatalogRef.MetadataObjectIDs");
	IDTypesDetails.Types().Add("CatalogRef.ExtensionObjectIDs");
	
	// Model options distribution considering subsystems nesting.
	DistributionTree = New ValueTree;
	DistributionTree.Columns.Add("Subsystem");
	DistributionTree.Columns.Add("SubsystemRef", IDTypesDetails);
	DistributionTree.Columns.Add("Variants", New TypeDescription("Array"));
	DistributionTree.Columns.Add("OptionsCount", New TypeDescription("Number"));
	DistributionTree.Columns.Add("EmptyRowsNumber", New TypeDescription("Number"));
	DistributionTree.Columns.Add("TotalNestedOptions", New TypeDescription("Number"));
	DistributionTree.Columns.Add("TotalNestedSubsystems", New TypeDescription("Number"));
	DistributionTree.Columns.Add("TotalNestedEmptyRows", New TypeDescription("Number"));
	DistributionTree.Columns.Add("NestingLevel", New TypeDescription("Number"));
	DistributionTree.Columns.Add("TopLevel", New TypeDescription("Boolean"));
	
	MaxNestingLevel = 0;
	
	For Each Subsystem In FillingParameters.SectionSubsystems Do
		
		ParentLevelRow = DistributionTree.Rows.Find(Subsystem.ParentRef, "SubsystemRef", True);
		If ParentLevelRow = Undefined Then
			TreeRow = DistributionTree.Rows.Add();
		Else
			TreeRow = ParentLevelRow.Rows.Add();
		EndIf;
		
		TreeRow.Subsystem = Subsystem;
		TreeRow.SubsystemRef = Subsystem.Ref;
		
		If DisplayWithoutGroups Then
			If Subsystem.Ref = FillingParameters.SectionRef Then
				For Each Option In Options Do
					TreeRow.Variants.Add(Option);
				EndDo;
			EndIf;
		Else
			TreeRow.Variants = Options.FindRows(New Structure("Subsystem", Subsystem.Ref));
		EndIf;
		TreeRow.OptionsCount = TreeRow.Variants.Count();
		
		HasOptions = TreeRow.OptionsCount > 0;
		If Not HasOptions Then
			TreeRow.EmptyRowsNumber = -1;
		EndIf;
		
		// Calculate a nesting level, Calculate number in the hierarchy (if there are options).
		If ParentLevelRow <> Undefined Then
			While ParentLevelRow <> Undefined Do
				If HasOptions Then
					ParentLevelRow.TotalNestedOptions = ParentLevelRow.TotalNestedOptions + TreeRow.OptionsCount;
					ParentLevelRow.TotalNestedSubsystems = ParentLevelRow.TotalNestedSubsystems + 1;
					ParentLevelRow.TotalNestedEmptyRows = ParentLevelRow.TotalNestedEmptyRows + 1;
				EndIf;
				ParentLevelRow = ParentLevelRow.Parent;
				TreeRow.NestingLevel = TreeRow.NestingLevel + 1;
			EndDo;
		EndIf;
		
		MaxNestingLevel = Max(MaxNestingLevel, TreeRow.NestingLevel);
		
	EndDo;
	
	// Calculate the placement column and the necessity of moving each subsystem basing on the count data.
	FillingParameters.Insert("MaxNestingLevel", MaxNestingLevel);
	DistributionTree.Columns.Add("FormGroup");
	DistributionTree.Columns.Add("OutputStarted", New TypeDescription("Boolean"));
	RootRow = DistributionTree.Rows[0];
	StringsCount = RootRow.OptionsCount + RootRow.TotalNestedOptions + RootRow.TotalNestedSubsystems + Max(RootRow.TotalNestedEmptyRows - 2, 0);
	
	// Variables to support the dynamics of level 3 groups.
	ColumnsNumber = Level2Group.ChildItems.Count();
	If RootRow.OptionsCount = 0 Then
		If ColumnsNumber > 1 AND RootRow.TotalNestedOptions <= 5 Then
			ColumnsNumber = 1;
		ElsIf ColumnsNumber > 2 AND RootRow.TotalNestedOptions <= 10 Then
			ColumnsNumber = 2;
		EndIf;
	EndIf;
	// Number of options to display in one column.
	Level3GroupCutoff = Max(Int(StringsCount / ColumnsNumber), 2);
	
	DisplayOrder = New ValueTable;
	DisplayOrder.Columns.Add("ColumnNumber", New TypeDescription("Number"));
	DisplayOrder.Columns.Add("IsSubsystem", New TypeDescription("Boolean"));
	DisplayOrder.Columns.Add("IsFollowUp", New TypeDescription("Boolean"));
	DisplayOrder.Columns.Add("IsOption", New TypeDescription("Boolean"));
	DisplayOrder.Columns.Add("IsEmptyRow", New TypeDescription("Boolean"));
	DisplayOrder.Columns.Add("TreeRow");
	DisplayOrder.Columns.Add("Subsystem");
	DisplayOrder.Columns.Add("SubsystemRef", IDTypesDetails);
	DisplayOrder.Columns.Add("SubsystemPriority", New TypeDescription("String"));
	DisplayOrder.Columns.Add("Variant");
	DisplayOrder.Columns.Add("OptionRef");
	DisplayOrder.Columns.Add("NestingLevel", New TypeDescription("Number"));
	
	Recursion = New Structure;
	Recursion.Insert("TotalObjectsToOutput", StringsCount);
	Recursion.Insert("FreeColumns", ColumnsNumber - 1);
	Recursion.Insert("ColumnsCount", ColumnsNumber);
	Recursion.Insert("Level3GroupCutoff", Level3GroupCutoff);
	Recursion.Insert("CurrentColumnNumber", 1);
	Recursion.Insert("IsLastColumn", Recursion.CurrentColumnNumber = Recursion.ColumnsCount Or StringsCount <= 6);
	Recursion.Insert("FreeRows", Level3GroupCutoff);
	Recursion.Insert("DisplayingStartedInCurrentColumn", False);
	
	FillDisplayOrder(DisplayOrder, Undefined, RootRow, Recursion, FillingParameters);
	
	// Output to a form
	CurrentColumnNumber = 0;
	For Each DisplayOrderRow In DisplayOrder Do
		
		If CurrentColumnNumber <> DisplayOrderRow.ColumnNumber Then
			CurrentColumnNumber = DisplayOrderRow.ColumnNumber;
			CurrentNestingLevel = 0;
			CurrentGroup = Level2Group.ChildItems.Get(CurrentColumnNumber - 1);
			CurrentGroupsByNestingLevels = New Map;
			CurrentGroupsByNestingLevels.Insert(0, CurrentGroup);
		EndIf;
		
		If DisplayOrderRow.IsSubsystem Then
			
			If DisplayOrderRow.SubsystemRef = FillingParameters.SectionRef Then
				CurrentNestingLevel = 0;
				CurrentGroup = CurrentGroupsByNestingLevels.Get(0);
			Else
				CurrentNestingLevel = DisplayOrderRow.NestingLevel;
				ToGroup = CurrentGroupsByNestingLevels.Get(DisplayOrderRow.NestingLevel - 1);
				CurrentGroup = AddSubsystemsGroup(FillingParameters, DisplayOrderRow, ToGroup);
				CurrentGroupsByNestingLevels.Insert(CurrentNestingLevel, CurrentGroup);
			EndIf;
			
		ElsIf DisplayOrderRow.IsOption Then
			
			If CurrentNestingLevel <> DisplayOrderRow.NestingLevel Then
				CurrentNestingLevel = DisplayOrderRow.NestingLevel;
				CurrentGroup = CurrentGroupsByNestingLevels.Get(CurrentNestingLevel);
			EndIf;
			
			AddReportOptionItems(FillingParameters, DisplayOrderRow.Variant, CurrentGroup, DisplayOrderRow.NestingLevel);
			
			If DisplayOrderRow.Variant.SubordinateCount > 0 Then
				CurrentNestingLevel = CurrentNestingLevel + 1;
				CurrentGroup = AddGroupWithIndent(FillingParameters, DisplayOrderRow, CurrentGroup);
				CurrentGroupsByNestingLevels.Insert(CurrentNestingLevel, CurrentGroup);
			EndIf;
			
		ElsIf DisplayOrderRow.IsEmptyRow Then
			
			ToGroup = CurrentGroupsByNestingLevels.Get(DisplayOrderRow.NestingLevel - 1);
			AddEmptyDecoration(FillingParameters, ToGroup);
			
		EndIf;
		
	EndDo;
	
	For ColumnNumber = 3 To Level2Group.ChildItems.Count() Do
		FoundItems = DisplayOrder.FindRows(New Structure("ColumnNumber, IsSubsystem", ColumnNumber, False));
		If FoundItems.Count() = 0 Then
			Level3Group = Level2Group.ChildItems.Get(ColumnNumber - 1);
			AddEmptyDecoration(FillingParameters, Level3Group);
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillDisplayOrder(DisplayOrder, ParentLevelRow, TreeRow, Recursion, FillingParameters)
	
	If Not Recursion.IsLastColumn AND Recursion.FreeRows <= 0 Then // the current column is exhausted
		// Go to a new column.
		Recursion.TotalObjectsToOutput = Recursion.TotalObjectsToOutput - 1; // An empty group that must not be displayed.
		Recursion.CurrentColumnNumber = Recursion.CurrentColumnNumber + 1;
		Recursion.IsLastColumn = (Recursion.CurrentColumnNumber = Recursion.ColumnsCount);
		FreeColumns = Recursion.ColumnsCount - Recursion.CurrentColumnNumber + 1;
		// Number of options to display in one column.
		Recursion.Level3GroupCutoff = Max(Int(Recursion.TotalObjectsToOutput / FreeColumns), 2);
		Recursion.FreeRows = Recursion.Level3GroupCutoff; // Number of options to display in one column.
		
		// Display the hierarchy / Repeat the hierarchy with the "(continue)" addition if you started 
		// outputting rows of the current parent in the previous column.
		CurrentParent = ParentLevelRow;
		While CurrentParent <> Undefined AND CurrentParent.SubsystemRef <> FillingParameters.SectionRef Do
			
			// Recursion.TotalObjectsToOutput will not decrease as continuation output increases the number of rows.
			OutputSubsystem = DisplayOrder.Add();
			OutputSubsystem.ColumnNumber        = Recursion.CurrentColumnNumber;
			OutputSubsystem.IsSubsystem       = True;
			OutputSubsystem.IsFollowUp      = ParentLevelRow.OutputStarted;
			OutputSubsystem.TreeRow        = TreeRow;
			OutputSubsystem.SubsystemPriority = TreeRow.Subsystem.Priority;
			FillPropertyValues(OutputSubsystem, CurrentParent, "Subsystem, SubsystemRef, NestingLevel");
			
			CurrentParent = CurrentParent.Parent;
		EndDo;
		
		Recursion.DisplayingStartedInCurrentColumn = False;
		
	EndIf;
	
	If (TreeRow.OptionsCount > 0 Or TreeRow.TotalNestedOptions > 0) AND Recursion.DisplayingStartedInCurrentColumn AND ParentLevelRow.OutputStarted Then
		// Display an empty row.
		Recursion.TotalObjectsToOutput = Recursion.TotalObjectsToOutput - 1;
		OutputEmptyRow = DisplayOrder.Add();
		OutputEmptyRow.ColumnNumber        = Recursion.CurrentColumnNumber;
		OutputEmptyRow.IsEmptyRow     = True;
		OutputEmptyRow.TreeRow        = TreeRow;
		OutputEmptyRow.SubsystemPriority = TreeRow.Subsystem.Priority;
		FillPropertyValues(OutputEmptyRow, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
		
		// Count rows occupied by empty rows.
		Recursion.FreeRows = Recursion.FreeRows - 1;
	EndIf;
	
	// Group output.
	If ParentLevelRow <> Undefined Then
		OutputSubsystem = DisplayOrder.Add();
		OutputSubsystem.ColumnNumber        = Recursion.CurrentColumnNumber;
		OutputSubsystem.IsSubsystem       = True;
		OutputSubsystem.TreeRow        = TreeRow;
		OutputSubsystem.SubsystemPriority = TreeRow.Subsystem.Priority;
		FillPropertyValues(OutputSubsystem, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
	EndIf;
	
	If TreeRow.OptionsCount > 0 Then
		
		// Count rows occupied by a group.
		Recursion.TotalObjectsToOutput = Recursion.TotalObjectsToOutput - 1;
		Recursion.FreeRows = Recursion.FreeRows - 1;
		
		TreeRow.OutputStarted = True;
		Recursion.DisplayingStartedInCurrentColumn = True;
		
		If Recursion.IsLastColumn
			Or ParentLevelRow <> Undefined
			AND (TreeRow.OptionsCount <= 5
			Or TreeRow.OptionsCount - 2 <= Recursion.FreeRows + 2) Then
			
			// Display all in the current column.
			CanBeContinued = False;
			NumberToCurrentColumn = TreeRow.OptionsCount;
			
		Else
			
			// Partial output to the current column and proceed in the next column.
			CanBeContinued = True;
			NumberToCurrentColumn = Max(Recursion.FreeRows + 2, 3);
			
		EndIf;
		
		// Register options in the current column / Continue displaying options in a new column.
		OptionsDisplayed = 0;
		VisibleOptionsCount = 0;
		For Each Option In TreeRow.Variants Do
			// TreeRow.Options is a result of a search in a value table.
			// The code assumes that the search result sorting does not differ from the row sorting.
			// If they differ, you must copy the source table with a filter by subsystem and sort it by 
			// description.
			
			If CanBeContinued
				AND Not Recursion.IsLastColumn
				AND Not Option.OutputWithMainReport
				AND OptionsDisplayed >= NumberToCurrentColumn Then
				// Go to a new column.
				Recursion.CurrentColumnNumber = Recursion.CurrentColumnNumber + 1;
				Recursion.IsLastColumn = (Recursion.CurrentColumnNumber = Recursion.ColumnsCount);
				FreeColumns = Recursion.ColumnsCount - Recursion.CurrentColumnNumber + 1;
				// Number of options to display in one column.
				Recursion.Level3GroupCutoff = Max(Int(Recursion.TotalObjectsToOutput / FreeColumns), 2);
				Recursion.FreeRows = Recursion.Level3GroupCutoff; // Number of options to display in one column.
				
				If Recursion.IsLastColumn Then
					NumberToCurrentColumn = -1;
				Else
					NumberToCurrentColumn = Max(Min(Recursion.FreeRows, TreeRow.OptionsCount - OptionsDisplayed), 3);
				EndIf;
				OptionsDisplayed = 0;
				
				// Repeat the hierarchy with the  "(continue)" addition.
				CurrentParent = ParentLevelRow;
				While CurrentParent <> Undefined AND CurrentParent.SubsystemRef <> FillingParameters.SectionRef Do
					
					// Recursion.TotalObjectsToOutput will not decrease as continuation output increases the number of rows.
					OutputSubsystem = DisplayOrder.Add();
					OutputSubsystem.ColumnNumber        = Recursion.CurrentColumnNumber;
					OutputSubsystem.IsSubsystem       = True;
					OutputSubsystem.IsFollowUp      = True;
					OutputSubsystem.TreeRow        = TreeRow;
					OutputSubsystem.SubsystemPriority = TreeRow.Subsystem.Priority;
					FillPropertyValues(OutputSubsystem, CurrentParent, "Subsystem, SubsystemRef, NestingLevel");
					
					CurrentParent = CurrentParent.Parent;
				EndDo;
				
				// Display a group with the "(continue)" addition.
				// Recursion.TotalObjectsToOutput will not decrease as continuation output increases the number of rows.
				OutputSubsystem = DisplayOrder.Add();
				OutputSubsystem.ColumnNumber        = Recursion.CurrentColumnNumber;
				OutputSubsystem.IsSubsystem       = True;
				OutputSubsystem.IsFollowUp      = True;
				OutputSubsystem.TreeRow        = TreeRow;
				OutputSubsystem.SubsystemPriority = TreeRow.Subsystem.Priority;
				FillPropertyValues(OutputSubsystem, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
				
				// Count rows occupied by a group.
				Recursion.FreeRows = Recursion.FreeRows - 1;
			EndIf;
			
			Recursion.TotalObjectsToOutput = Recursion.TotalObjectsToOutput - 1;
			OutputOption = DisplayOrder.Add();
			OutputOption.ColumnNumber        = Recursion.CurrentColumnNumber;
			OutputOption.IsOption          = True;
			OutputOption.TreeRow        = TreeRow;
			OutputOption.Variant             = Option;
			OutputOption.OptionRef       = Option.Ref;
			OutputOption.SubsystemPriority = TreeRow.Subsystem.Priority;
			FillPropertyValues(OutputOption, TreeRow, "Subsystem, SubsystemRef, NestingLevel");
			If Option.OutputWithMainReport Then
				OutputOption.NestingLevel = OutputOption.NestingLevel + 1;
			EndIf;
			
			OptionsDisplayed = OptionsDisplayed + 1;
			If Option.Visible Then
				VisibleOptionsCount = VisibleOptionsCount + 1;
			EndIf;
			
			// Count rows occupied by options.
			Recursion.FreeRows = Recursion.FreeRows - 1;
		EndDo;
		
		If VisibleOptionsCount > 0 Then
			SubsystemForms = FindSubsystemByRef(ThisObject, TreeRow.SubsystemRef);
			SubsystemForms.VisibleOptionsCount = SubsystemForms.VisibleOptionsCount + VisibleOptionsCount;
			While SubsystemForms.Ref <> SubsystemForms.SectionRef Do
				SubsystemForms = FindSubsystemByRef(ThisObject, SubsystemForms.SectionRef);
				SubsystemForms.VisibleOptionsCount = SubsystemForms.VisibleOptionsCount + VisibleOptionsCount;
			EndDo;
		EndIf;
		
	EndIf;
	
	// Register nested rows.
	For Each SubordinateObjectRow In TreeRow.Rows Do
		FillDisplayOrder(DisplayOrder, TreeRow, SubordinateObjectRow, Recursion, FillingParameters);
		// OutputStarted forwarding from the lower level.
		If SubordinateObjectRow.OutputStarted Then
			TreeRow.OutputStarted = True;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Function AddSubsystemsGroup(FillingParameters, DisplayOrderRow, ToGroup)
	Subsystem = DisplayOrderRow.Subsystem;
	TreeRow = DisplayOrderRow.TreeRow;
	If TreeRow.OptionsCount = 0
		AND TreeRow.TotalNestedOptions = 0
		AND Not (SetupMode AND FillingParameters.NameOfGroup = "WithGroup") Then
		Return ToGroup;
	EndIf;
	SubsystemPresentation = Subsystem.Presentation;
	
	Subsystem.ItemNumber = Subsystem.ItemNumber + 1;
	SubsystemGroupName = Subsystem.ItemName + "_" + Format(Subsystem.ItemNumber, "NG=0");
	
	If Not FillingParameters.CurrentSectionOnly Then
		While Items.Find(SubsystemGroupName) <> Undefined Do
			Subsystem.ItemNumber = Subsystem.ItemNumber + 1;
			SubsystemGroupName = Subsystem.ItemName + "_" + Format(Subsystem.ItemNumber, "NG=0");
		EndDo;
	EndIf;
	
	// Add indent to the left.
	If DisplayOrderRow.NestingLevel > 1 Then
		// Group.
		IndentGroup = Items.Insert(SubsystemGroupName + "_GroupIndent", Type("FormGroup"), ToGroup);
		IndentGroup.Type                      = FormGroupType.UsualGroup;
		IndentGroup.Group              = ChildFormItemsGroup.AlwaysHorizontal;
		IndentGroup.Representation              = UsualGroupRepresentation.None;
		IndentGroup.ShowTitle      = False;
		IndentGroup.HorizontalStretch = True;
		
		// Picture.
		IndentPicture = Items.Insert(SubsystemGroupName + "_IndentPicture", Type("FormDecoration"), IndentGroup);
		FillPropertyValues(IndentPicture, FillingParameters.Templates.IndentPicture);
		IndentPicture.Width = DisplayOrderRow.NestingLevel - 1;
		If DisplayOrderRow.TreeRow.OptionsCount = 0 AND DisplayOrderRow.TreeRow.TotalNestedOptions = 0 Then
			IndentPicture.Visible = False;
		EndIf;
		
		// Higher level group substitution.
		ToGroup = IndentGroup;
		
		TitleFont = NormalGroupFont;
	Else
		TitleFont = ImportantGroupFont;
	EndIf;
	
	SubsystemsGroup = Items.Insert(SubsystemGroupName, Type("FormGroup"), ToGroup);
	SubsystemsGroup.Type = FormGroupType.UsualGroup;
	SubsystemsGroup.HorizontalStretch = True;
	SubsystemsGroup.Group = ChildFormItemsGroup.Vertical;
	SubsystemsGroup.Representation = UsualGroupRepresentation.None;
	
	NeedsHighlighting = False;
	If FillingParameters.UseHighlighting Then
		HighlightingParameters = FillingParameters.SearchResult.SubsystemsHighlight.Get(Subsystem.Ref);
		If HighlightingParameters <> Undefined Then
			PresentationHighlighting = HighlightingParameters.SubsystemDescription;
			If PresentationHighlighting.FoundWordsCount > 0 Then
				NeedsHighlighting = True;
			EndIf;
		EndIf;
	EndIf;
	
	If NeedsHighlighting Then
		If DisplayOrderRow.IsFollowUp Then
			Suffix = NStr("ru = '(продолжение)'; en = '(continue)'; pl = '(ciąg dalszy)';es_ES = '(continuar)';es_CO = '(continuar)';tr = '(devam)';it = '(continua)';de = '(weiter)'");
			If Not StrEndsWith(PresentationHighlighting.Value, Suffix) Then
				PresentationHighlighting.Value = PresentationHighlighting.Value + " " + Suffix;
			EndIf;
		EndIf;
		
		SubsystemsGroup.ShowTitle = False;
		SubsystemsGroup.ToolTipRepresentation = ToolTipRepresentation.ShowTop;
		
		FormattedString = GenerateRowWithHighlighting(PresentationHighlighting);
		
		SubsystemTitle = Items.Insert(SubsystemsGroup.Name + "_ExtendedTooltip", Type("FormDecoration"), SubsystemsGroup);
		SubsystemTitle.Title  = FormattedString;
		SubsystemTitle.TextColor = ReportsOptionsGroupColor;
		SubsystemTitle.Font      = TitleFont;
		SubsystemTitle.HorizontalStretch = True;
		SubsystemTitle.Height = 1;
		
	Else
		If DisplayOrderRow.IsFollowUp Then
			SubsystemPresentation = SubsystemPresentation + " " + NStr("ru = '(продолжение)'; en = '(continue)'; pl = '(ciąg dalszy)';es_ES = '(continuar)';es_CO = '(continuar)';tr = '(devam)';it = '(continua)';de = '(weiter)'");
		EndIf;
		
		SubsystemsGroup.ShowTitle = True;
		SubsystemsGroup.Title           = SubsystemPresentation;
		SubsystemsGroup.TitleTextColor = ReportsOptionsGroupColor;
		SubsystemsGroup.TitleFont      = TitleFont;
	EndIf;
	
	TreeRow.FormGroup = SubsystemsGroup;
	
	Return SubsystemsGroup;
EndFunction

&AtServer
Function AddGroupWithIndent(FillingParameters, DisplayOrderRow, ToGroup)
	FillingParameters.OptionItemsDisplayed = FillingParameters.OptionItemsDisplayed + 1;
	
	IndentGroupName   = "IndentGroup_" + Format(FillingParameters.OptionItemsDisplayed, "NG=0");
	IndentPictureName = "IndentPicture_" + Format(FillingParameters.OptionItemsDisplayed, "NG=0");
	OutputGroupName    = "OutputGroup_" + Format(FillingParameters.OptionItemsDisplayed, "NG=0");
	
	// Indent.
	IndentGroup = Items.Insert(IndentGroupName, Type("FormGroup"), ToGroup);
	IndentGroup.Type                      = FormGroupType.UsualGroup;
	IndentGroup.Group              = ChildFormItemsGroup.AlwaysHorizontal;
	IndentGroup.Representation              = UsualGroupRepresentation.None;
	IndentGroup.ShowTitle      = False;
	IndentGroup.HorizontalStretch = True;
	
	// Picture.
	IndentPicture = Items.Insert(IndentPictureName, Type("FormDecoration"), IndentGroup);
	FillPropertyValues(IndentPicture, FillingParameters.Templates.IndentPicture);
	IndentPicture.Width = 1;
	
	// Output.
	OutputGroup = Items.Insert(OutputGroupName, Type("FormGroup"), IndentGroup);
	OutputGroup.Type                      = FormGroupType.UsualGroup;
	OutputGroup.Group              = ChildFormItemsGroup.Vertical;
	OutputGroup.Representation              = UsualGroupRepresentation.None;
	OutputGroup.ShowTitle      = False;
	OutputGroup.HorizontalStretch = True;
	
	Return OutputGroup;
EndFunction

&AtServer
Function AddReportOptionItems(FillingParameters, Option, ToGroup, NestingLevel = 0)
	
	// A unique name of an item to be added.
	LabelName = "Option_" + ReportsClientServer.CastIDToName(Option.Ref.UUID());
	If ValueIsFilled(Option.Subsystem) Then
		LabelName = LabelName
			+ "_Subsystem_"
			+ ReportsClientServer.CastIDToName(Option.Subsystem.UUID());
	EndIf;
	If Not FillingParameters.CurrentSectionOnly AND Items.Find(LabelName) <> Undefined Then
		If ValueIsFilled(Option.SectionRef) Then
			Number = 0;
			Suffix = "_Section_" + ReportsClientServer.CastIDToName(Option.SectionRef.UUID());
		Else
			Number = 1;
			Suffix = "_1";
		EndIf;
		While Items.Find(LabelName + Suffix) <> Undefined Do
			Number = Number + 1;
			Suffix = "_" + String(Number);
		EndDo;
		LabelName = LabelName + Suffix;
	EndIf;
	
	If SetupMode Then
		OptionGroupName = "Group_" + LabelName;
		OptionGroup = Items.Insert(OptionGroupName, Type("FormGroup"), ToGroup);
		OptionGroup.Type = FormGroupType.UsualGroup;
		FillPropertyValues(OptionGroup, FillingParameters.Templates.OptionGroup);
	Else
		OptionGroup = ToGroup;
	EndIf;
	
	// Add a check box (it is not used for quick access).
	If SetupMode Then
		CheckBoxName = "CheckBox_" + LabelName;
		
		FormAttribute = New FormAttribute(CheckBoxName, New TypeDescription("Boolean"), , , False);
		FillingParameters.AttributesToAdd.Add(FormAttribute);
		
		CheckBox = Items.Insert(CheckBoxName, Type("FormField"), OptionGroup);
		CheckBox.Type = FormFieldType.CheckBoxField;
		CheckBox.TitleLocation = FormItemTitleLocation.None;
		CheckBox.Visible = (FillingParameters.NameOfGroup <> "QuickAccess");
		CheckBox.SetAction("OnChange", "Attachable_OptionVisibilityOnChange");
	EndIf;
	
	// Add a report option hyperlink title.
	Label = Items.Insert(LabelName, Type("FormDecoration"), OptionGroup);
	FillPropertyValues(Label, FillingParameters.Templates.OptionLabel);
	Label.Title = TrimAll(Option.Description);
	If ValueIsFilled(Option.Details) Then
		Label.ToolTip = TrimAll(Option.Details);
	EndIf;
	If ValueIsFilled(Option.Author) Then
		Label.ToolTip = TrimL(Label.ToolTip + Chars.LF) + NStr("ru = 'Автор:'; en = 'Author:'; pl = 'Autor:';es_ES = 'Autor:';es_CO = 'Autor:';tr = 'Yazar:';it = 'Autore:';de = 'Autor:'") + " " + TrimAll(String(Option.Author));
	EndIf;
	Label.SetAction("Click", "Attachable_OptionClick");
	If Not Option.Visible Then
		Label.TextColor = HiddenOptionsColor;
	EndIf;
	If Option.Important
		AND FillingParameters.NameOfGroup <> "SeeAlso"
		AND FillingParameters.NameOfGroup <> "QuickAccess" Then
		Label.Font = ImportantLabelFont;
	EndIf;
	Label.AutoMaxWidth = False;
	
	TooltipContent = New Array;
	DefineOptionTooltipContent(FillingParameters, Option, TooltipContent, Label);
	OutputOptionTooltip(Label, TooltipContent);
	
	If SetupMode Then
		For Each KeyAndValue In FillingParameters.ContextMenu Do
			CommandName = KeyAndValue.Key;
			ButtonName = CommandName + "_" + LabelName;
			Button = Items.Insert(ButtonName, Type("FormButton"), Label.ContextMenu);
			If WebClient Then
				Command = Commands.Add(ButtonName);
				FillPropertyValues(Command, Commands[CommandName]);
				Button.CommandName = ButtonName;
			Else
				Button.CommandName = CommandName;
			EndIf;
			FillPropertyValues(Button, KeyAndValue.Value);
		EndDo;
	EndIf;
	
	// Register an added label.
	TableRow = AddedOptions.Add();
	FillPropertyValues(TableRow, Option);
	TableRow.Level2GroupName     = FillingParameters.NameOfGroup;
	TableRow.LabelName           = LabelName;
	
	FillingParameters.SearchForOptions.Insert(LabelName, TableRow.GetID());
	
	Return Label;
	
EndFunction

&AtServer
Procedure DefineOptionTooltipContent(FillingParameters, Option, TooltipContent, Label)
	TooltipDisplayed = False;
	If FillingParameters.UseHighlighting Then
		HighlightingParameters = FillingParameters.SearchResult.OptionsHighlight.Get(Option.Ref);
		If HighlightingParameters <> Undefined Then
			If HighlightingParameters.OptionDescription.FoundWordsCount > 0 Then
				Label.Title = GenerateRowWithHighlighting(HighlightingParameters.OptionDescription);
			EndIf;
			If HighlightingParameters.Details.FoundWordsCount > 0 Then
				GenerateRowWithHighlighting(HighlightingParameters.Details, TooltipContent);
				TooltipDisplayed = True;
			EndIf;
			If HighlightingParameters.AuthorPresentation.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("ru = 'Автор:'; en = 'Author:'; pl = 'Autor:';es_ES = 'Autor:';es_CO = 'Autor:';tr = 'Yazar:';it = 'Autore:';de = 'Autor:'") + " ");
				GenerateRowWithHighlighting(HighlightingParameters.AuthorPresentation, TooltipContent);
				TooltipContent.Add(".");
				TooltipDisplayed = True;
			EndIf;
			If HighlightingParameters.UserSettingsDescriptions.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("ru = 'Сохраненные настройки:'; en = 'Saved setting:'; pl = 'Zapisane ustawienia:';es_ES = 'Configuraciones guardadas:';es_CO = 'Configuraciones guardadas:';tr = 'Kaydedilmiş ayarlar:';it = 'Impostazioni salvate:';de = 'Gespeicherte Einstellungen:'") + " ");
				GenerateRowWithHighlighting(HighlightingParameters.UserSettingsDescriptions, TooltipContent);
				TooltipContent.Add(".");
				TooltipDisplayed = True;
			EndIf;
			If HighlightingParameters.FieldDescriptions.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("ru = 'Поля:'; en = 'Fields:'; pl = 'Pola:';es_ES = 'Campos:';es_CO = 'Campos:';tr = 'Alanlar:';it = 'Campi:';de = 'Felder:'") + " ");
				GenerateRowWithHighlighting(HighlightingParameters.FieldDescriptions, TooltipContent);
				TooltipContent.Add(".");
				TooltipDisplayed = True;
			EndIf;
			If HighlightingParameters.FilterParameterDescriptions.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("ru = 'Настройки:'; en = 'Settings:'; pl = 'Ustawienia:';es_ES = 'Ajustes:';es_CO = 'Ajustes:';tr = 'Ayarlar:';it = 'Impostazioni:';de = 'Einstellungen:'") + " ");
				GenerateRowWithHighlighting(HighlightingParameters.FilterParameterDescriptions, TooltipContent);
				TooltipContent.Add(".");
				TooltipDisplayed = True;
			EndIf;
			If HighlightingParameters.Keywords.FoundWordsCount > 0 Then
				If TooltipContent.Count() > 0 Then
					TooltipContent.Add(Chars.LF);
				EndIf;
				TooltipContent.Add(NStr("ru = 'Ключевые слова:'; en = 'Keywords:'; pl = 'Słowa kluczowe:';es_ES = 'Palabras claves:';es_CO = 'Palabras claves:';tr = 'Anahtar kelimeler:';it = 'Parole chiave:';de = 'Schlüsselwörter:'") + " ");
				GenerateRowWithHighlighting(HighlightingParameters.Keywords, TooltipContent);
				TooltipContent.Add(".");
				TooltipDisplayed = True;
			EndIf;
		EndIf;
	EndIf;
	If Not TooltipDisplayed AND ShowTooltips Then
		TooltipContent.Add(TrimAll(Label.ToolTip));
	EndIf;
EndProcedure

&AtServer
Procedure OutputOptionTooltip(Label, TooltipContent)
	If TooltipContent.Count() = 0 Then
		Return;
	EndIf;
	
	Label.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
	
	Tooltip = Label.ExtendedTooltip;
	Tooltip.Title                = New FormattedString(TooltipContent);
	Tooltip.TextColor               = TooltipColor;
	Tooltip.AutoMaxHeight   = False;
	Tooltip.MaxHeight       = 3;
	Tooltip.HorizontalStretch = True;
	Tooltip.AutoMaxWidth   = False;
	Tooltip.MaxWidth       = 0;
EndProcedure

&AtServer
Function GenerateRowWithHighlighting(SearchArea, Content = Undefined)
	ReturnFormattedRow = False;
	If Content = Undefined Then
		ReturnFormattedRow = True;
		Content = New Array;
	EndIf;
	
	SourceText = SearchArea.Value;
	TextShortened = False;
	TextLength = StrLen(SourceText);
	If TextLength > 150 Then
		TextShortened = ShortenText(SourceText, TextLength, 150);
	EndIf;
	
	SearchArea.WordHighlighting.SortByValue(SortDirection.Asc);
	NumberOpen = 0;
	NormalTextStartPosition = 1;
	HighlightingStartPosition = 0;
	For Each ListItem In SearchArea.WordHighlighting Do
		If TextShortened AND ListItem.Value > TextLength Then
			ListItem.Value = TextLength; // If a text was shortened, adjust highlighting.
		EndIf;
		Highlight = (ListItem.Presentation = "+");
		NumberOpen = NumberOpen + ?(Highlight, 1, -1);
		If Highlight AND NumberOpen = 1 Then
			HighlightingStartPosition = ListItem.Value;
			NormalTextFragment = Mid(SourceText, NormalTextStartPosition, HighlightingStartPosition - NormalTextStartPosition);
			Content.Add(NormalTextFragment);
		ElsIf Not Highlight AND NumberOpen = 0 Then
			NormalTextStartPosition = ListItem.Value;
			HighlightedFragment = Mid(SourceText, HighlightingStartPosition, NormalTextStartPosition - HighlightingStartPosition);
			Content.Add(New FormattedString(HighlightedFragment, , , SearchResultsHighlightColor));
		EndIf;
	EndDo;
	If NormalTextStartPosition <= TextLength Then
		NormalTextFragment = Mid(SourceText, NormalTextStartPosition);
		Content.Add(NormalTextFragment);
	EndIf;
	
	If ReturnFormattedRow Then
		Return New FormattedString(Content);
	Else
		Return Undefined;
	EndIf;
EndFunction

&AtServer
Function ShortenText(Text, CurrentLength, LengthLimit)
	LFPosition = StrFind(Text, Chars.LF, SearchDirection.FromEnd, LengthLimit);
	PointPosition = StrFind(Text, ".", SearchDirection.FromEnd, LengthLimit);
	CommaPosition = StrFind(Text, ",", SearchDirection.FromEnd, LengthLimit);
	SemicolonPosition = StrFind(Text, ",", SearchDirection.FromEnd, LengthLimit);
	Position = Max(LFPosition, PointPosition, CommaPosition, SemicolonPosition);
	If Position = 0 Then
		LFPosition = StrFind(Text, Chars.LF, SearchDirection.FromBegin, LengthLimit);
		PointPosition = StrFind(Text, ".", SearchDirection.FromBegin, LengthLimit);
		CommaPosition = StrFind(Text, ",", SearchDirection.FromBegin, LengthLimit);
		SemicolonPosition = StrFind(Text, ",", SearchDirection.FromBegin, LengthLimit);
		Position = Min(LFPosition, PointPosition, CommaPosition, SemicolonPosition);
	EndIf;
	If Position = 0 Or Position = CurrentLength Then
		Return False;
	EndIf;
	Text = Left(Text, Position) + " ...";
	CurrentLength = Position;
	Return True;
EndFunction

&AtServer
Function AddEmptyDecoration(FillingParameters, ToGroup)
	
	FillingParameters.EmptyDecorationsAdded = FillingParameters.EmptyDecorationsAdded + 1;
	DecorationName = "EmptyDecoration_" + Format(FillingParameters.EmptyDecorationsAdded, "NG=0");
	
	Decoration = Items.Insert(DecorationName, Type("FormDecoration"), ToGroup);
	Decoration.Type = FormDecorationType.Label;
	Decoration.Title = " ";
	Decoration.HorizontalStretch = True;
	
	Return Decoration;
	
EndFunction

&AtClient
Procedure MobileApplicationDescriptionClick(Item)
	
	FormParameters = ClientParameters.MobileApplicationDescription;
	OpenForm(FormParameters.FormName, FormParameters.FormParameters, ThisObject); 
	
EndProcedure

#EndRegion
