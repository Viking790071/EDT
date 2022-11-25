////////////////////////////////////////////////////////////////////////////////
// Standard functionality

#Region StandardFunctionality

&AtClient
Procedure GroupFieldsUnavailable()
	
	Items.GroupFieldsPages.CurrentPage = Items.UnavailableGroupFieldsSettings;
					
EndProcedure

&AtClient
Procedure SelectedFieldsAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemSelection(StructureItem) Then
				
		LocalSelectedFields = True;
		Items.SelectionFieldsPages.CurrentPage = Items.SelectedFieldsSettings;
			
	Else
			
		LocalSelectedFields = False;
		Items.SelectionFieldsPages.CurrentPage = Items.DisabledSelectedFieldsSettings;
			
	EndIf;
		
	Items.LocalSelectedFields.ReadOnly = False;
					
EndProcedure

&AtClient
Procedure SelectedFieldsUnavailable()
	
	LocalSelectedFields = False;
	Items.LocalSelectedFields.ReadOnly = True;
	Items.SelectionFieldsPages.CurrentPage = Items.UnavailableSelectedFieldsSettings;
					
EndProcedure

&AtClient
Procedure FilterAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemFilter(StructureItem) Then
		
		LocalFilter = True;
		Items.FilterPages.CurrentPage = Items.FilterSettings;
			
	Else
		
		LocalFilter = False;
		Items.FilterPages.CurrentPage = Items.DisabledFilterSettings;
			
	EndIf;
			
	Items.LocalFilter.ReadOnly = False;
	
EndProcedure

&AtClient
Procedure FilterUnavailable()
	
	LocalFilter = False;
	Items.LocalFilter.ReadOnly = True;
	Items.FilterPages.CurrentPage = Items.UnavailableFilterSettings;
		
EndProcedure

&AtClient
Procedure OrderAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemOrder(StructureItem) Then
		
		LocalOrder = True;
		Items.OrderPages.CurrentPage = Items.OrderSettings;
					
	Else
		
		LocalOrder = False;
		Items.OrderPages.CurrentPage = Items.DisabledOrderSettings;
					
	EndIf;
			
	Items.LocalOrder.ReadOnly = False;
		
EndProcedure

&AtClient
Procedure OrderUnavailable()
	
	LocalOrder = False;
	Items.LocalOrder.ReadOnly = True;
	Items.OrderPages.CurrentPage = Items.UnavailableOrderSettings;
		
EndProcedure

&AtClient
Procedure ConditionalAppearanceAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemConditionalAppearance(StructureItem) Then
		
		LocalConditionalAppearance = True;
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettings;
					
	Else
		
		LocalConditionalAppearance = False;
		Items.ConditionalAppearancePages.CurrentPage = Items.DisabledConditionalAppearanceSettings;
					
	EndIf;
			
	Items.LocalConditionalAppearance.ReadOnly = False;
		
EndProcedure

&AtClient
Procedure ConditionalAppearanceUnavailable()
	
	LocalConditionalAppearance = False;
	Items.LocalConditionalAppearance.ReadOnly = True;
	Items.ConditionalAppearancePages.CurrentPage = Items.UnavailableConditionalAppearanceSettings;
		
EndProcedure

&AtClient
Procedure OutputParametersAvailable(StructureItem)
	
	If Report.SettingsComposer.Settings.HasItemOutputParameters(StructureItem) Then
		
		LocalOutputParameters = True;
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettings;
					
	Else
		
		LocalOutputParameters = False;
		Items.OutputParametersPages.CurrentPage = Items.DisabledOutputParametersSettings;
					
	EndIf;
			
	Items.LocalOutputParameters.ReadOnly = False;
		
EndProcedure

&AtClient
Procedure OutputParametersUnavailable()
	
	LocalOutputParameters = False;
	Items.LocalOutputParameters.ReadOnly = True;
	Items.OutputParametersPages.CurrentPage = Items.UnavailableOutputParametersSettings;
	
EndProcedure

&AtClient
Procedure SettingsComposerSettingsOnActivateField(Item)
		
	Var SelectedPage;
	
	If Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsChoiceAvailable" Then
		
		SelectedPage = Items.SelectionFieldsPage;
		
	ElsIf Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsFilterAvailable" Then
		
		SelectedPage = Items.FilterPage;
		
	ElsIf Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsOrderAvailable" Then
		
		SelectedPage = Items.OrderPage;
		
	ElsIf Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsConditionalAppearanceAvailable" Then
		
		SelectedPage = Items.ConditionalAppearancePage;
		
	ElsIf Items.SettingSettingsComposer.CurrentItem.Name = "SettingsComposerSettingsOutputParametersAvailable" Then
		
		SelectedPage = Items.OutputParametersPage;
		
	EndIf;
	
	If SelectedPage <> Undefined Then
		
		Items.SettingsPages.CurrentPage = SelectedPage;
		
	EndIf;

EndProcedure

&AtClient
Procedure SettingsComposerSettingsOnActivateRow(Item)
	
	StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
	ItemType = TypeOf(StructureItem); 
	
	If ItemType = Undefined
		Or ItemType = Type("DataCompositionChartStructureItemCollection")
		Or ItemType = Type("DataCompositionTableStructureItemCollection") Then
		
		GroupFieldsUnavailable();
		SelectedFieldsUnavailable();
		FilterUnavailable();
		OrderUnavailable();
		ConditionalAppearanceUnavailable();
		OutputParametersUnavailable();
		
	ElsIf ItemType = Type("DataCompositionSettings")
		Or ItemType = Type("DataCompositionNestedObjectSettings") Then
		
		GroupFieldsUnavailable();
		
		LocalSelectedFields = True;
		Items.LocalSelectedFields.ReadOnly = True;
		Items.SelectionFieldsPages.CurrentPage = Items.SelectedFieldsSettings;
		
		LocalFilter = True;
		Items.LocalFilter.ReadOnly = True;
		Items.FilterPages.CurrentPage = Items.FilterSettings;
		
		LocalOrder = True;
		Items.LocalOrder.ReadOnly = True;
		Items.OrderPages.CurrentPage = Items.OrderSettings;
		
		LocalConditionalAppearance = True;
		Items.LocalConditionalAppearance.ReadOnly = True;
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettings;
		
		LocalOutputParameters = True;
		Items.LocalOutputParameters.ReadOnly = True;
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettings;
		
	ElsIf ItemType = Type("DataCompositionGroup")
		Or ItemType = Type("DataCompositionTableGroup")
		Or ItemType = Type("DataCompositionChartGroup") Then
		
		Items.GroupFieldsPages.CurrentPage = Items.GroupFieldsSettings;
		
		SelectedFieldsAvailable(StructureItem);
		FilterAvailable(StructureItem);
		OrderAvailable(StructureItem);
		ConditionalAppearanceAvailable(StructureItem);
		OutputParametersAvailable(StructureItem);
		
	ElsIf ItemType = Type("DataCompositionTable")
		Or ItemType = Type("DataCompositionChart") Then
		
		GroupFieldsUnavailable();
		SelectedFieldsAvailable(StructureItem);
		FilterUnavailable();
		OrderUnavailable();
		ConditionalAppearanceAvailable(StructureItem);
		OutputParametersAvailable(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToReport(Item)
	
	StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
	ItemSettings =  Report.SettingsComposer.Settings.ItemSettings(StructureItem);
	Items.SettingSettingsComposer.CurrentRow = Report.SettingsComposer.Settings.GetIDByObject(ItemSettings);
	
EndProcedure

&AtClient
Procedure LocalSelectedFieldsOnChange(Item)
	
	If LocalSelectedFields Then
		
		Items.SelectionFieldsPages.CurrentPage = Items.SelectedFieldsSettings;
			
	Else
		
		Items.SelectionFieldsPages.CurrentPage = Items.DisabledSelectedFieldsSettings;

		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemSelection(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LocalFilterOnChange(Item)
	
	If LocalFilter Then
		
		Items.FilterPages.CurrentPage = Items.FilterSettings;
			
	Else
		
		Items.FilterPages.CurrentPage = Items.DisabledFilterSettings;

		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemFilter(StructureItem);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LocalOrderOnChange(Item)
	
	If LocalOrder Then
		
		Items.OrderPages.CurrentPage = Items.OrderSettings;
					
	Else
		
		Items.OrderPages.CurrentPage = Items.DisabledOrderSettings;
					
		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemOrder(StructureItem);
		
	EndIf;
				
EndProcedure

&AtClient
Procedure LocalConditionalAppearanceOnChange(Item)

	If LocalConditionalAppearance Then
		
		Items.ConditionalAppearancePages.CurrentPage = Items.ConditionalAppearanceSettings;
					
	Else
		
		Items.ConditionalAppearancePages.CurrentPage = Items.DisabledConditionalAppearanceSettings;
					
		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemConditionalAppearance(StructureItem);
					
	EndIf;
				
EndProcedure

&AtClient
Procedure LocalOutputParametersOnChange(Item)
	
	If LocalOutputParameters Then
		
		Items.OutputParametersPages.CurrentPage = Items.OutputParametersSettings;
					
	Else
		
		Items.OutputParametersPages.CurrentPage = Items.DisabledOutputParametersSettings;
					
		StructureItem = Report.SettingsComposer.Settings.GetObjectByID(Items.SettingSettingsComposer.CurrentRow);
		Report.SettingsComposer.Settings.ClearItemOutputParameters(StructureItem);
	EndIf;
			
EndProcedure

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	ParametersForm = New Structure(
		"PurposeUseKey, UserSettingsKey,
		|Details, GenerateOnOpen, ReadOnly,
		|FixedSettings, Section, Subsystem, SubsystemPresentation");
	FillPropertyValues(ParametersForm, Parameters);
	ParametersForm.Insert("Filter", New Structure);
	If TypeOf(Parameters.Filter) = Type("Structure") Then
		CommonClientServer.SupplementStructure(ParametersForm.Filter, Parameters.Filter, True);
		Parameters.Filter.Clear();
	EndIf;
	
	If Parameters.Property("VariantPresentation") AND ValueIsFilled(Parameters.VariantPresentation) Then
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Изменение варианта отчета ""%1""'; en = 'Change report option ""%1""'; pl = 'Zmień wariant raportu ""%1""';es_ES = 'Cambiar la opción del informe ""%1""';es_CO = 'Cambiar la opción del informe ""%1""';tr = '""%1"" rapor seçeneğini değiştir';it = 'Modificare la variante di report ""%1""';de = 'Ändern der Berichtsoption ""%1""'"), Parameters.VariantPresentation);
	EndIf;
	
	If Parameters.Property("ReportSettings", ReportSettings) Then
		If ReportSettings.SchemaModified Then
			Report.SettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL));
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(Parameters.VariantPresentation) Then
		Parameters.Property("DescriptionOption", Parameters.VariantPresentation);
	EndIf;
	
	FullPath = CommonClientServer.StructureProperty(Parameters, "FullPathToCurrentDCNode");
	If ValueIsFilled(FullPath) Then
		DCSettings = CommonClientServer.StructureProperty(Parameters, "Variant");
		If DCSettings = Undefined Then
			DCSettings = Report.SettingsComposer.Settings;
		EndIf;
		RootNode = ReportsClientServer.FindItemByFullPath(DCSettings, FullPath);
		If RootNode <> Undefined Then
			CurrentDCNodeID = DCSettings.GetIDByObject(RootNode);
		EndIf;
	EndIf;
	If TypeOf(CurrentDCNodeID) <> Type("DataCompositionID") Then
		CurrentDCNodeID = CommonClientServer.StructureProperty(Parameters, "CurrentRow");
		If TypeOf(CurrentDCNodeID) <> Type("DataCompositionID") Then
			CurrentDCNodeID = CommonClientServer.StructureProperty(Parameters, "CurrentDCNodeID");
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeLoadVariantAtServer(Settings)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If TypeOf(ParametersForm.Filter) = Type("Structure") Then
		ReportsServer.SetFixedFilters(ParametersForm.Filter, Settings, ReportSettings);
	EndIf;
EndProcedure

&AtServer
Procedure OnLoadUserSettingsAtServer(Settings)
	NewDCSettings = Report.SettingsComposer.GetSettings();
	Report.SettingsComposer.LoadFixedSettings(New DataCompositionSettings);
	ReportsClientServer.LoadSettings(Report.SettingsComposer, NewDCSettings);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If TypeOf(CurrentDCNodeID) = Type("DataCompositionID") Then
		AttachIdleHandler("SetCurrentRow", 0.1, True);
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CompleteEditing(Command)
	If ModalMode
		Or WindowOpeningMode = FormWindowOpeningMode.LockWholeInterface
		Or FormOwner = Undefined Then
		Close(True);
	Else
		SelectionResult = New Structure;
		SelectionResult.Insert("VariantModified", VariantModified);
		SelectionResult.Insert("UserSettingsModified", VariantModified Or UserSettingsModified);
		
		#If WebClient Then
			SelectionResult.VariantModified = True; // For a platform.
			SelectionResult.UserSettingsModified = True;
		#EndIf
		
		If SelectionResult.VariantModified Then
			SelectionResult.Insert("DCSettings", Report.SettingsComposer.Settings);
		EndIf;
		If SelectionResult.UserSettingsModified Then
			SelectionResult.Insert("ResetUserSettings", True);
		EndIf;
		
		NotifyChoice(SelectionResult);
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SetCurrentRow()
	Items.SettingSettingsComposer.CurrentRow = CurrentDCNodeID;
EndProcedure

#EndRegion
