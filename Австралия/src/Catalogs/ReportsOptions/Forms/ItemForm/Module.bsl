#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then 
		Return;
	EndIf;
	If Parameters.Property("ReportFormOpeningParameters", ReportFormOpeningParameters) Then
		Return;
	EndIf;
	
	InfobaseUpdate.CheckObjectProcessed(Object, ThisObject);
	
	Available = ?(Object.AvailableToAuthorOnly, "1", "2");
	
	// Read properties of a predefined object;
	// Fill in attributes linked to a predefined object upon opening.
	ReadPredefinedObjectProperties(True);
	
	FullRightsToOptions = ReportsOptions.FullRightsToOptions();
	RightToThisOption = FullRightsToOptions Or Object.Author = Users.AuthorizedUser();
	If Not RightToThisOption Then
		ReadOnly = True;
		Items.SubsystemsTree.ReadOnly = True;
	EndIf;
	
	If Object.DeletionMark Then
		Items.SubsystemsTree.ReadOnly = True;
	EndIf;
	
	If Not Object.Custom Then
		Items.Description.ReadOnly = True;
		Items.Available.ReadOnly = True;
		Items.Author.ReadOnly = True;
		Items.Author.AutoMarkIncomplete = False;
	EndIf;
	
	IsExternal = (Object.ReportType = Enums.ReportTypes.External);
	If IsExternal Then
		Items.SubsystemsTree.ReadOnly = True;
	EndIf;
	
	Items.Available.ReadOnly = Not FullRightsToOptions;
	Items.Author.ReadOnly = Not FullRightsToOptions;
	Items.VisibleByDefault.ReadOnly = Not FullRightsToOptions;
	Items.TechnicalInformation.Visible = FullRightsToOptions;
	
	// Fill in a report name for the "View" command.
	If Object.ReportType = Enums.ReportTypes.Internal
		Or Object.ReportType = Enums.ReportTypes.Extension Then
		ReportName = Object.Report.Name;
	ElsIf Object.ReportType = Enums.ReportTypes.Additional Then
		ReportName = Object.Report.ObjectName;
	Else
		ReportName = Object.Report;
	EndIf;
	
	RefillTree(False);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	If ReportFormOpeningParameters <> Undefined Then
		Cancel = True;
		ReportsOptionsClient.OpenReportForm(Undefined, ReportFormOpeningParameters);
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If Source <> ThisObject
		AND (EventName = ReportsOptionsClientServer.EventNameChangingOption()
			Or EventName = "Write_ConstantsSet") Then
		RefillTree(True);
		Items.SubsystemsTree.Expand(SubsystemsTree.GetItems()[0].GetID(), True);
	EndIf;
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	// Write properties linked to a predefined report option.
	If TypeOf(PredefinedOptionProperties) = Type("FixedStructure") Then
		CurrentObject.DefaultVisibilityOverridden = 
			Object.VisibleByDefault <> PredefinedOptionProperties.VisibleByDefault;
		
		If Not IsBlankString(Object.Details) AND Lower(TrimAll(Object.Details)) = Lower(TrimAll(PredefinedOptionProperties.Details)) Then
			CurrentObject.Details = "";
		EndIf;
	EndIf;
	
	// Write a subsystems tree.
	DestinationTree = FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
	If CurrentObject.IsNew() Then
		ChangedSections = DestinationTree.Rows.FindRows(New Structure("Use", 1), True);
	Else
		ChangedSections = DestinationTree.Rows.FindRows(New Structure("Modified", True), True);
	EndIf;
	ReportsOptions.SubsystemsTreeWrite(CurrentObject, ChangedSections);
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	RefillTree(False);
	ReadPredefinedObjectProperties(False);
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	NotificationParameter = New Structure("Ref, Description, Author, Details");
	FillPropertyValues(NotificationParameter, Object);
	Notify(ReportsOptionsClientServer.EventNameChangingOption(), NotificationParameter, ThisObject);
	StandardSubsystemsClient.ExpandTreeNodes(ThisObject, "SubsystemsTree", "*", True);
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ReportsOptionsClient.EditMultilineText(ThisObject, Item.EditText, Object, "Details", NStr("ru = 'Описание'; en = 'Details'; pl = 'Szczegóły';es_ES = 'Detalles';es_CO = 'Detalles';tr = 'Ayrıntılar';it = 'Dettagli';de = 'Details'"));
EndProcedure

&AtClient
Procedure AvailableOnChange(Item)
	Object.AvailableToAuthorOnly = (ThisObject.Available = "1");
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersSubsystemsTree

&AtClient
Procedure SubsystemsTreeUsingOnChange(Item)
	ReportsOptionsClient.SubsystemsTreeUsingOnChange(ThisObject, Item);
EndProcedure

&AtClient
Procedure SubsystemsTreeImportanceOnChange(Item)
	ReportsOptionsClient.SubsystemsTreeImportanceOnChange(ThisObject, Item);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	ReportsOptions.SetSubsystemsTreeConditionalAppearance(ThisObject);
	
EndProcedure

&AtServer
Function RefillTree(Read)
	SelectedRows = ReportsServer.RememberSelectedRows(ThisObject, "SubsystemsTree", "Ref");
	If Read Then
		ThisObject.Read();
	EndIf;
	DestinationTree = ReportsOptions.SubsystemsTreeGenerate(ThisObject, Object);
	ValueToFormAttribute(DestinationTree, "SubsystemsTree");
	ReportsServer.RestoreSelectedRows(ThisObject, "SubsystemsTree", SelectedRows);
	Return True;
EndFunction

&AtServer
Procedure ReadPredefinedObjectProperties(FirstReading)
	If FirstReading Then
		If Not Object.Custom
			AND (Object.ReportType = Enums.ReportTypes.Internal
				Or Object.ReportType = Enums.ReportTypes.Extension)
			AND ValueIsFilled(Object.PredefinedVariant) Then // Read settings of a predefined object.
			Information = Common.ObjectAttributesValues(Object.PredefinedVariant, "VisibleByDefault, Details");
			PredefinedOptionProperties = New FixedStructure(Information);
		Else
			Return; // Not a predefined object.
		EndIf;
	Else
		If TypeOf(PredefinedOptionProperties) <> Type("FixedStructure") Then
			Return; // Not a predefined object.
		EndIf;
	EndIf;
	
	If Object.DefaultVisibilityOverridden = False Then
		Object.VisibleByDefault = PredefinedOptionProperties.VisibleByDefault;
	EndIf;
	
	If IsBlankString(Object.Details) Then
		Object.Details = PredefinedOptionProperties.Details;
	EndIf;
EndProcedure

#EndRegion
