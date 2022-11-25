
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	UserRef             = Parameters.User;
	SettingsOperation           = Parameters.SettingsOperation;
	InfoBaseUser = DataProcessors.UsersSettings.IBUserName(UserRef);
	CurrentUserRef      = Users.CurrentUser();
	CurrentUser            = DataProcessors.UsersSettings.IBUserName(CurrentUserRef);
	
	SelectedSettingsPage = Items.SettingsTypes.CurrentPage.Name;
	
	PersonalSettingsFormName = 
		Common.CommonCoreParameters().PersonalSettingsFormName;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If DataSavedToSettingsStorage
	   AND TypeOf(FormOwner) = Type("ClientApplicationForm") Then
		
		Properties = New Structure("ClearSettingsSelectionHistory", False);
		FillPropertyValues(FormOwner, Properties);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnSaveDataInSettingsAtServer(Settings)
	
	Settings.Insert("SearchChoiceList", Items.Search.ChoiceList.UnloadValues());
	
	Settings.Delete("Interface");
	Settings.Delete("ReportSettings");
	Settings.Delete("OtherSettings");
	
	InterfaceTree       = FormAttributeToValue("Interface");
	ReportSettingsTree = FormAttributeToValue("ReportSettings");
	OtherSettingsTree  = FormAttributeToValue("OtherSettings");
	
	MarkedInterfaceSettings = MarkedSettings(InterfaceTree);
	MarkedReportSettings      = MarkedSettings(ReportSettingsTree);
	MarkedOtherSettings       = MarkedSettings(OtherSettingsTree);
	
	Settings.Insert("MarkedInterfaceSettings", MarkedInterfaceSettings);
	Settings.Insert("MarkedReportSettings",      MarkedReportSettings);
	Settings.Insert("MarkedOtherSettings",       MarkedOtherSettings);
	
	DataSavedToSettingsStorage = True;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	AllSelectedSettings = New Structure;
	AllSelectedSettings.Insert("MarkedInterfaceSettings");
	AllSelectedSettings.Insert("MarkedReportSettings");
	AllSelectedSettings.Insert("MarkedOtherSettings");
	
	If Parameters.ClearSettingsSelectionHistory Then
		Settings.Clear();
		Return;
	EndIf;
	
	SearchChoiceList = Settings.Get("SearchChoiceList");
	If TypeOf(SearchChoiceList) = Type("Array") Then
		Items.Search.ChoiceList.LoadValues(SearchChoiceList);
	EndIf;
	Search = "";
	
	MarkedInterfaceSettings = Settings.Get("MarkedInterfaceSettings");
	MarkedReportSettings      = Settings.Get("MarkedReportSettings");
	MarkedOtherSettings       = Settings.Get("MarkedOtherSettings");
	
	AllSelectedSettings.MarkedInterfaceSettings = MarkedInterfaceSettings;
	AllSelectedSettings.MarkedReportSettings = MarkedReportSettings;
	AllSelectedSettings.MarkedOtherSettings = MarkedOtherSettings;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateSettingsList();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OnChangePage(Item, CurrentPage)
	
	SelectedSettingsPage = CurrentPage.Name;
	
EndProcedure

&AtClient
Procedure SearchOnChange(Item)
	
	If ValueIsFilled(Search) Then
		ChoiceList = Items.Search.ChoiceList;
		ListItem = ChoiceList.FindByValue(Search);
		If ListItem = Undefined Then
			ChoiceList.Insert(0, Search);
			If ChoiceList.Count() > 10 Then
				ChoiceList.Delete(10);
			EndIf;
		Else
			Index = ChoiceList.IndexOf(ListItem);
			If Index <> 0 Then
				ChoiceList.Move(Index, -Index);
			EndIf;
		EndIf;
		CurrentItem = Items.Search;
	EndIf;
	
	SettingsSearch = True;
	UpdateSettingsList();
	
EndProcedure

&AtClient
Procedure SettingsTreeChoice(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	UsersInternalClient.OpenReportOrForm(
		CurrentItem, InfoBaseUser, CurrentUser, PersonalSettingsFormName);
	
EndProcedure

&AtClient
Procedure CheckOnChange(Item)
	
	ChangeMark(Item);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Update(Command)
	
	SettingsSearch = False;
	UpdateSettingsList();
	
EndProcedure

&AtClient
Procedure OpenSettingsItem(Command)
	
	UsersInternalClient.OpenReportOrForm(
		CurrentItem, InfoBaseUser, CurrentUser, PersonalSettingsFormName);
	
EndProcedure

&AtClient
Procedure SelectAll(Command)
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		SettingsTree = ReportSettings.GetItems();
		MarkTreeItems(SettingsTree, True);
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		SettingsTree = Interface.GetItems();
		MarkTreeItems(SettingsTree, True);
	Else
		SettingsTree = OtherSettings.GetItems();
		MarkTreeItems(SettingsTree, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ClearAll(Command)
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		SettingsTree = ReportSettings.GetItems();
		MarkTreeItems(SettingsTree, False);
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		SettingsTree = Interface.GetItems();
		MarkTreeItems(SettingsTree, False);
	Else
		SettingsTree = OtherSettings.GetItems();
		MarkTreeItems(SettingsTree, False);
	EndIf;
	
EndProcedure

&AtClient
Procedure Select(Command)
	
	Result = New Structure;
	
	SelectedInterfaceSettings    = SelectedSettings(Interface);
	SelectedReportSettings         = SelectedSettings(ReportSettings);
	SelectedOtherSettingsStructure = SelectedSettings(OtherSettings);
	
	SettingsCount = SelectedInterfaceSettings.SettingsCount
	                   + SelectedReportSettings.SettingsCount
	                   + SelectedOtherSettingsStructure.SettingsCount;
	
	If SelectedReportSettings.SettingsCount = 1 Then
		SettingsPresentations = SelectedReportSettings.SettingsPresentations;
	ElsIf SelectedInterfaceSettings.SettingsCount = 1 Then
		SettingsPresentations = SelectedInterfaceSettings.SettingsPresentations;
	ElsIf SelectedOtherSettingsStructure.SettingsCount = 1 Then
		SettingsPresentations = SelectedOtherSettingsStructure.SettingsPresentations;
	EndIf;
	
	Result.Insert("Interface",       SelectedInterfaceSettings.SettingsArray);
	Result.Insert("ReportSettings", SelectedReportSettings.SettingsArray);
	Result.Insert("OtherSettings",  SelectedOtherSettingsStructure.SettingsArray);
	
	Result.Insert("SettingsPresentations", SettingsPresentations);
	Result.Insert("SettingsCount",    SettingsCount);
	
	Result.Insert("ReportOptionTable",  UserReportOptionTable);
	Result.Insert("SelectedReportsOptions", SelectedReportSettings.ReportsOptions);
	
	Result.Insert("PersonalSettings",           SelectedOtherSettingsStructure.PersonalSettingsArray);
	Result.Insert("OtherUserSettings", SelectedOtherSettingsStructure.OtherUserSettings);
	
	Close(Result);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions related to displaying settings to users.

&AtClient
Procedure UpdateSettingsList()
	
	Items.QuickSearch.Enabled = False;
	Items.CommandBar.Enabled = False;
	Items.TimeConsumingOperationPages.CurrentPage = Items.TimeConsumingOperationPage;
	Result = UpdatingSettingsList();
	
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	CompletionNotification = New NotifyDescription("UpdateSettingsListCompletion", ThisObject);
	
	TimeConsumingOperationsClient.WaitForCompletion(Result, CompletionNotification, IdleParameters);
	
EndProcedure

&AtServer
Function UpdatingSettingsList()
	
	If ExecutionResult <> Undefined
		AND ExecutionResult.JobID <> New UUID("00000000-0000-0000-0000-000000000000") Then
		TimeConsumingOperations.CancelJobExecution(ExecutionResult.JobID);
	EndIf;
	
	If SettingsSearch Then
		MarkedTreeItems();
	EndIf;
	
	TimeConsumingOperationParameters = TimeConsumingOperationParameters();
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.WaitForCompletion = 0; // run immediately
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Обновление настроек пользователей'; en = 'Update user settings'; pl = 'Aktualizacja ustawień użytkowników';es_ES = 'Actualización de los ajustes de usuarios';es_CO = 'Actualización de los ajustes de usuarios';tr = 'Kullanıcı ayarlarının güncellenmesi';it = 'Aggiorna impostazioni utente';de = 'Aktualisieren der Benutzereinstellungen'");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground("UsersInternal.FillSettingsLists",
		TimeConsumingOperationParameters, ExecutionParameters);
	
	Return ExecutionResult;
	
EndFunction

&AtClient
Procedure UpdateSettingsListCompletion(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	If Result.Status = "Completed" Then
		FillSettings();
		ExpandValueTree();
		Items.TimeConsumingOperationPages.CurrentPage = Items.SettingsPage;
		Items.QuickSearch.Enabled = True;
		Items.CommandBar.Enabled = True;
	ElsIf Result.Status = "Error" Then
		Items.TimeConsumingOperationPages.CurrentPage = Items.SettingsPage;
		Raise Result.BriefErrorPresentation;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSettings()
	Result = GetFromTempStorage(ExecutionResult.ResultAddress);
	
	ValueToFormAttribute(Result.ReportSettingsTree, "ReportSettings");
	ValueToFormAttribute(Result.UserReportOptions, "UserReportOptionTable");
	ValueToFormAttribute(Result.InterfaceSettings, "Interface");
	ValueToFormAttribute(Result.OtherSettingsTree, "OtherSettings");
	
	If SettingsSearch
		Or Not InitialSettingsImported 
		AND AllSelectedSettings <> Undefined Then
		ImportMarkValues(ReportSettings, AllSelectedSettings.MarkedReportSettings, "ReportSettings");
		ImportMarkValues(Interface, AllSelectedSettings.MarkedInterfaceSettings, "Interface");
		ImportMarkValues(OtherSettings, AllSelectedSettings.MarkedOtherSettings, "OtherSettings");
		InitialSettingsImported = True;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

&AtClient
Procedure ChangeMark(Item)
	
	MarkedItem = Item.Parent.Parent.CurrentData;
	MarkValue = MarkedItem.Check;
	
	If MarkValue = 2 Then
		MarkValue = 0;
		MarkedItem.Check = MarkValue;
	EndIf;
	
	ItemParent = MarkedItem.GetParent();
	SubordinateItems = MarkedItem.GetItems();
	SettingsCount = 0;
	
	If ItemParent = Undefined Then
		
		For Each SubordinateItem In SubordinateItems Do
			
			If SubordinateItem.Check <> MarkValue Then
				SettingsCount = SettingsCount + 1
			EndIf;
			
			SubordinateItem.Check = MarkValue;
		EndDo;
		
		If SubordinateItems.Count() = 0 Then
			SettingsCount = SettingsCount + 1;
		EndIf;
		
	Else
		CheckSubordinateItemMarksAndMarkParent(ItemParent, MarkValue);
		SettingsCount = SettingsCount + 1;
	EndIf;
	
	SettingsCount = ?(MarkValue, SettingsCount, -SettingsCount);
	// Updating settings page title.
	RefreshPageTitle(SettingsCount);
	
EndProcedure

&AtClient
Procedure RefreshPageTitle(SettingsCount)
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		
		ReportSettingsCount = ReportSettingsCount + SettingsCount;
		
		If ReportSettingsCount = 0 Then
			TitleText = NStr("ru='Настройки отчетов'; en = 'Report settings'; pl = 'Ustawienia raportu';es_ES = 'Configuraciones de informe';es_CO = 'Configuraciones de informe';tr = 'Rapor ayarları';it = 'Impostazioni del report';de = 'Berichteinstellungen'");
		Else
			TitleText = NStr("ru='Настройки отчетов (%1)'; en = 'Report settings (%1)'; pl = 'Ustawienia raportu (%1)';es_ES = 'Configuraciones del informe (%1)';es_CO = 'Configuraciones del informe (%1)';tr = 'Rapor ayarları (%1)';it = 'Impostazioni dei report  (%1)';de = 'Berichteinstellungen (%1)'");
			TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, ReportSettingsCount);
		EndIf;
		
		Items.ReportSettingsPage.Title = TitleText;
		
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		
		InterfaceSettingsCount = InterfaceSettingsCount + SettingsCount;
		If InterfaceSettingsCount = 0 Then
			TitleText = NStr("ru='Внешний вид'; en = 'Interface settings'; pl = 'Ustawienia wyglądu';es_ES = 'Configuraciones del aspecto';es_CO = 'Configuraciones del aspecto';tr = 'Görünüm ayarları';it = 'Impostazioni interfaccia';de = 'Aussehen Einstellungen'");
		Else
			TitleText = NStr("ru='Внешний вид (%1)'; en = 'Interface settings (%1)'; pl = 'Formatowanie (%1)';es_ES = 'Aspecto (%1)';es_CO = 'Aspecto (%1)';tr = 'Düzenleme (%1)';it = 'Impostazioni interfaccia (%1)';de = 'Erscheinen (%1)'");
			TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, InterfaceSettingsCount);
		EndIf;
		
		Items.InterfacePage.Title = TitleText;
		
	ElsIf SelectedSettingsPage = "OtherSettingsPage" Then
		
		OtherSettingsCount = OtherSettingsCount + SettingsCount;
		If OtherSettingsCount = 0 Then
			TitleText = NStr("ru='Прочие настройки'; en = 'Other settings'; pl = 'Inne ustawienia';es_ES = 'Otras configuraciones';es_CO = 'Otras configuraciones';tr = 'Diğer ayarlar';it = 'Altre impostazioni';de = 'Andere Einstellungen'");
		Else
			TitleText = NStr("ru='Прочие настройки (%1)'; en = 'Other settings (%1)'; pl = 'Inne ustawienia (%1)';es_ES = 'Otras configuraciones (%1)';es_CO = 'Otras configuraciones (%1)';tr = 'Diğer ayarlar (%1)';it = 'Altre impostazioni (%1)';de = 'Andere Einstellungen (%1)'");
			TitleText = StringFunctionsClientServer.SubstituteParametersToString(TitleText, OtherSettingsCount);
		EndIf;
		
		Items.OtherSettingsPage.Title = TitleText;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckSubordinateItemMarksAndMarkParent(TreeItem, MarkValue)
	
	HasUnmarkedItems = False;
	HasMarkedItems = False;
	
	SubordinateItems = TreeItem.GetItems();
	If SubordinateItems = Undefined Then
		TreeItem.Check = MarkValue;
	Else
		
		For Each SubordinateItem In SubordinateItems Do
			
			If SubordinateItem.Check = 0 Then
				HasUnmarkedItems = True;
			ElsIf SubordinateItem.Check = 1 Then
				HasMarkedItems = True;
			EndIf;
			
		EndDo;
		
		If HasUnmarkedItems 
			AND HasMarkedItems Then
			TreeItem.Check = 2;
		ElsIf HasMarkedItems Then
			TreeItem.Check = 1;
		Else
			TreeItem.Check = 0;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure MarkTreeItems(SettingsTree, MarkValue)
	
	SettingsCount = 0;
	For Each TreeItem In SettingsTree Do
		SubordinateItems = TreeItem.GetItems();
		
		For Each SubordinateItem In SubordinateItems Do
			
			SubordinateItem.Check = MarkValue;
			SettingsCount = SettingsCount + 1;
			
		EndDo;
		
		If SubordinateItems.Count() = 0 Then
			SettingsCount = SettingsCount + 1;
		EndIf;
		
		TreeItem.Check = MarkValue;
	EndDo;
	
	SettingsCount = ?(MarkValue, SettingsCount, 0);
	
	If SelectedSettingsPage = "ReportSettingsPage" Then
		ReportSettingsCount = SettingsCount;
	ElsIf SelectedSettingsPage = "InterfacePage" Then
		InterfaceSettingsCount = SettingsCount;
	ElsIf SelectedSettingsPage = "OtherSettingsPage" Then
		OtherSettingsCount = SettingsCount;
	EndIf;
	
	RefreshPageTitle(0);
	
EndProcedure

&AtClient
Function SelectedSettings(SettingsTree)
	
	SettingsArray = New Array;
	PersonalSettingsArray = New Array;
	SettingsPresentations = New Array;
	ReportOptionArray = New Array;
	OtherUserSettings = New Array;
	SettingsCount = 0;
	
	For Each Setting In SettingsTree.GetItems() Do
		
		If Setting.Check = 1 Then
			
			If Setting.Type = "PersonalSettings" Then
				PersonalSettingsArray.Add(Setting.Keys);
			ElsIf Setting.Type = "OtherUserSettingsItem" Then
				UserSettings = New Structure;
				UserSettings.Insert("SettingID", Setting.RowType);
				UserSettings.Insert("SettingValue", Setting.Keys);
				OtherUserSettings.Add(UserSettings);
			Else
				SettingsArray.Add(Setting.Keys);
				
				If Setting.Type = "PersonalOption" Then
					ReportOptionArray.Add(Setting.Keys);
				EndIf;
				
			EndIf;
			ChildItemCount = Setting.GetItems().Count();
			SettingsCount = SettingsCount + ?(ChildItemCount=0,1,ChildItemCount);
			
			If ChildItemCount = 1 Then
				
				ChildSettingsItem = Setting.GetItems()[0];
				SettingsPresentations.Add(Setting.Settings + " - " + ChildSettingsItem.Settings);
				
			ElsIf ChildItemCount = 0 Then
				SettingsPresentations.Add(Setting.Settings);
			EndIf;
			
		Else
			ChildSettings = Setting.GetItems();
			
			For Each ChildSettingsItem In ChildSettings Do
				
				If ChildSettingsItem.Check = 1 Then
					SettingsArray.Add(ChildSettingsItem.Keys);
					SettingsPresentations.Add(Setting.Settings + " - " + ChildSettingsItem.Settings);
					SettingsCount = SettingsCount + 1;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	SettingsStructure = New Structure;
	
	SettingsStructure.Insert("SettingsArray", SettingsArray);
	SettingsStructure.Insert("PersonalSettingsArray", PersonalSettingsArray);
	SettingsStructure.Insert("OtherUserSettings", OtherUserSettings);
	SettingsStructure.Insert("ReportsOptions", ReportOptionArray);
	SettingsStructure.Insert("SettingsPresentations", SettingsPresentations);
	SettingsStructure.Insert("SettingsCount", SettingsCount);
	
	Return SettingsStructure;
	
EndFunction

&AtClient
Procedure ExpandValueTree()
	
	Rows = ReportSettings.GetItems();
	For Each Row In Rows Do 
		Items.ReportSettingsTree.Expand(Row.GetID(), True);
	EndDo;
	
	Rows = Interface.GetItems();
	For Each Row In Rows Do 
		Items.Interface.Expand(Row.GetID(), True);
	EndDo;
	
EndProcedure

&AtServer
Function MarkedTreeItems()
	
	ReportSettingsTree = FormAttributeToValue("ReportSettings");
	InterfaceTree = FormAttributeToValue("Interface");
	OtherSettingsTree = FormAttributeToValue("OtherSettings");
	
	MarkedReportSettings = MarkedSettings(ReportSettingsTree);
	MarkedInterfaceSettings = MarkedSettings(InterfaceTree);
	MarkedOtherSettings = MarkedSettings(OtherSettingsTree);
	
	If AllSelectedSettings = Undefined Then
		
		AllSelectedSettings = New Structure;
		AllSelectedSettings.Insert("MarkedReportSettings", MarkedReportSettings);
		AllSelectedSettings.Insert("MarkedInterfaceSettings", MarkedInterfaceSettings);
		AllSelectedSettings.Insert("MarkedOtherSettings", MarkedOtherSettings);
		
	Else
		
		AllSelectedSettings.MarkedReportSettings = 
			SettingsMarkedAfterComparison(MarkedReportSettings, ReportSettingsTree, "ReportSettings");
		AllSelectedSettings.MarkedInterfaceSettings = 
			SettingsMarkedAfterComparison(MarkedInterfaceSettings, InterfaceTree, "Interface");
		AllSelectedSettings.MarkedOtherSettings = 
			SettingsMarkedAfterComparison(MarkedOtherSettings, OtherSettingsTree, "OtherSettings");
		
	EndIf;
	
EndFunction

&AtServer
Function TimeConsumingOperationParameters()
	
	TimeConsumingOperationParameters = New Structure;
	TimeConsumingOperationParameters.Insert("FormName");
	TimeConsumingOperationParameters.Insert("Search");
	TimeConsumingOperationParameters.Insert("SettingsOperation");
	TimeConsumingOperationParameters.Insert("InfoBaseUser");
	TimeConsumingOperationParameters.Insert("UserRef");
	
	FillPropertyValues(TimeConsumingOperationParameters, ThisObject);
	
	TimeConsumingOperationParameters.Insert("ReportSettingsTree",          FormAttributeToValue("ReportSettings"));
	TimeConsumingOperationParameters.Insert("InterfaceSettings",           FormAttributeToValue("Interface"));
	TimeConsumingOperationParameters.Insert("OtherSettingsTree",           FormAttributeToValue("OtherSettings"));
	TimeConsumingOperationParameters.Insert("UserReportOptions", FormAttributeToValue("UserReportOptionTable"));
	
	Return TimeConsumingOperationParameters;
	
EndFunction

&AtServer
Function MarkedSettings(SettingsTree)
	
	MarkedItemList = New ValueList;
	MarkedItemFilter = New Structure("Check", 1);
	UndefinedItemFilter = New Structure("Check", 2);
	
	MarkedItemArray = SettingsTree.Rows.FindRows(MarkedItemFilter, True);
	For Each ArrayRow In MarkedItemArray Do
		MarkedItemList.Add(ArrayRow.RowType, , True);
	EndDo;
	
	UndefinedItemArray = SettingsTree.Rows.FindRows(UndefinedItemFilter, True);
	For Each ArrayRow In UndefinedItemArray Do
		MarkedItemList.Add(ArrayRow.RowType);
	EndDo;
	
	Return MarkedItemList;
	
EndFunction

&AtServer
Function SettingsMarkedAfterComparison(MarkedSettings, SettingsTree, SettingsType)
	
	If SettingsType = "ReportSettings" Then
		SourceMarkedItemList = AllSelectedSettings.MarkedReportSettings;
	ElsIf SettingsType = "Interface" Then
		SourceMarkedItemList = AllSelectedSettings.MarkedInterfaceSettings;
	ElsIf SettingsType = "OtherSettings" Then
		SourceMarkedItemList = AllSelectedSettings.MarkedOtherSettings;
	EndIf;
	
	If SourceMarkedItemList = Undefined Then
		Return New ValueList;
	EndIf;
	
	For Each Item In SourceMarkedItemList Do
		
		FoundSetting = MarkedSettings.FindByValue(Item.Value);
		If FoundSetting = Undefined Then
			
			FilterParameters = New Structure("RowType", Item.Value);
			FoundSettingInTree = SettingsTree.Rows.FindRows(FilterParameters, True);
			If FoundSettingInTree.Count() = 0 Then
				MarkedSettings.Add(Item.Value, , Item.Check);
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return MarkedSettings;
EndFunction

&AtServer
Procedure ImportMarkValues(ValuesTree, MarkedSettings, SettingsType)
	
	If MarkedSettings = Undefined Then
		Return;
	EndIf;
	MarkedItemCount = 0;
	
	For Each MarkedSettingsRow In MarkedSettings Do
		
		MarkedSetting = MarkedSettingsRow.Value;
		
		For Each TreeRow In ValuesTree.GetItems() Do
			
			SubordinateItems = TreeRow.GetItems();
			
			If TreeRow.RowType = MarkedSetting Then
				
				If MarkedSettingsRow.Check Then
					TreeRow.Check = 1;
					
					If SubordinateItems.Count() = 0 Then
						MarkedItemCount = MarkedItemCount + 1;
					EndIf;
					
				Else
					TreeRow.Check = 2;
				EndIf;
				
			Else
				
				For Each SubordinateItem In SubordinateItems Do
					
					If SubordinateItem.RowType = MarkedSetting Then
						SubordinateItem.Check = 1;
						MarkedItemCount = MarkedItemCount + 1;
					EndIf;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If MarkedItemCount > 0 Then
		
		If SettingsType = "ReportSettings" Then
			ReportSettingsCount = MarkedItemCount;
			Items.ReportSettingsPage.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='Настройки отчетов (%1)'; en = 'Report settings (%1)'; pl = 'Ustawienia raportu (%1)';es_ES = 'Configuraciones del informe (%1)';es_CO = 'Configuraciones del informe (%1)';tr = 'Rapor ayarları (%1)';it = 'Impostazioni dei report  (%1)';de = 'Berichteinstellungen (%1)'"), MarkedItemCount);
		ElsIf SettingsType = "Interface" Then
			InterfaceSettingsCount = MarkedItemCount;
			Items.InterfacePage.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='Внешний вид (%1)'; en = 'Interface settings (%1)'; pl = 'Formatowanie (%1)';es_ES = 'Aspecto (%1)';es_CO = 'Aspecto (%1)';tr = 'Düzenleme (%1)';it = 'Impostazioni interfaccia (%1)';de = 'Erscheinen (%1)'"), MarkedItemCount);
		ElsIf SettingsType = "OtherSettings" Then
			OtherSettingsCount = MarkedItemCount;
			Items.OtherSettingsPage.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru='Прочие настройки (%1)'; en = 'Other settings (%1)'; pl = 'Inne ustawienia (%1)';es_ES = 'Otras configuraciones (%1)';es_CO = 'Otras configuraciones (%1)';tr = 'Diğer ayarlar (%1)';it = 'Altre impostazioni (%1)';de = 'Andere Einstellungen (%1)'"), MarkedItemCount);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
