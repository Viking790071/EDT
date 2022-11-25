#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("CurrentUser", Users.AuthorizedUser());
	Context.Insert("FullRightsToOptions", ReportsOptions.FullRightsToOptions());
	
	PrototypeKey = Parameters.CurrentSettingsKey;
	
	ReportInformation = ReportsOptions.GenerateReportInformationByFullName(Parameters.ObjectKey);
	If TypeOf(ReportInformation.ErrorText) = Type("String") Then
		Raise ReportInformation.ErrorText;
	EndIf;
	Context.Insert("ReportRef", ReportInformation.Report);
	Context.Insert("ReportName",    ReportInformation.ReportName);
	Context.Insert("ReportType",   ReportInformation.ReportType);
	Context.Insert("IsExternal",  ReportInformation.ReportType = Enums.ReportTypes.External);
	Context.Insert("SearchByDescription", New Map);
	
	FillOptionsList(False);
	
	Items.AvailableToGroup.ReadOnly = Not Context.FullRightsToOptions;
	If Context.IsExternal Then
		Items.ExternalReportDetails.Visible = True;
		Items.OptionDefaultVisibility.Visible = False;
		Items.Back.Visible = False;
		Items.Next.Visible = False;
		Items.AvailableToGroup.Visible = False;
		DeleteSecondLineInTitle(Items.WhatIsNextNewDecoration.Title);
		DeleteSecondLineInTitle(Items.WhatIsNextOverwriteDecoration.Title);
	EndIf;
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	If Not ValueIsFilled(DescriptionOption) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Name is not populated'; en = 'Name is not populated'; pl = 'Name is not populated';es_ES = 'Name is not populated';es_CO = 'Name is not populated';tr = 'Name is not populated';it = 'Name is not populated';de = 'Name is not populated'"),
			,
			"Description");
		Cancel = True;
	ElsIf ReportsOptions.DescriptionIsUsed(Context.ReportRef, OptionRef, DescriptionOption) Then
		CommonClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '""%1"" is already used, enter another Name.'; en = '""%1"" is already used, enter another Name.'; pl = '""%1"" is already used, enter another Name.';es_ES = '""%1"" is already used, enter another Name.';es_CO = '""%1"" is already used, enter another Name.';tr = '""%1"" is already used, enter another Name.';it = '""%1"" is already used, enter another Name.';de = '""%1"" is already used, enter another Name.'"),
				DescriptionOption),
			,
			"Description");
		Cancel = True;
	EndIf;
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If Source = FormName Then
		Return;
	EndIf;
	
	If EventName = ReportsOptionsClientServer.EventNameChangingOption()
		Or EventName = "Write_ConstantsSet" Then
		FillOptionsList(True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	CurrentItem = Items.Description;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DescriptionOnChange(Item)
	DescriptionModified = True;
	SetOptionSavingScenario();
EndProcedure

&AtClient
Procedure AvailableOnChange(Item)
	OptionForAuthorOnly = (Available = "AuthorOnly");
EndProcedure

&AtClient
Procedure DescriptionStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	Notification = New NotifyDescription("BeginSelectDetailsCompletion", ThisObject);
	CommonClient.ShowMultilineTextEditingForm(Notification, Items.Details.EditText,
		NStr("ru = 'Details'; en = 'Details'; pl = 'Details';es_ES = 'Details';es_CO = 'Details';tr = 'Details';it = 'Details';de = 'Details'"));
EndProcedure

&AtClient
Procedure DetailsOnChange(Item)
	DetailsModified = True;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersReportOptions

&AtClient
Procedure ReportOptionsOnActivateRow(Item)
	If Not DescriptionModified AND Not DetailsModified Then 
		AttachIdleHandler("SetOptionSavingScenarioDeferred", 0.1, True);
	EndIf;
	DescriptionModified = False;
	DetailsModified = False;
EndProcedure

&AtClient
Procedure ReportOptionsChoice(Item, RowSelected, Field, StandardProcessing)
	StandardProcessing = False;
	SaveAndLoad();
EndProcedure

&AtClient
Procedure ReportOptionsBeforeChangeRow(Item, Cancel)
	Cancel = True;
	OpenOptionForChange();
EndProcedure

&AtClient
Procedure ReportOptionsBeforeDelete(Item, Cancel)
	Cancel = True;
	Option = Items.ReportOptions.CurrentData;
	If Option = Undefined Or Not ValueIsFilled(Option.Ref) Then
		Return;
	EndIf;
	
	If Not Context.FullRightsToOptions AND Not Option.CurrentUserAuthor Then
		WarningText = NStr("ru = 'Insufficient rights to delete the report option ""%1"".'; en = 'Insufficient rights to delete the report option ""%1"".'; pl = 'Insufficient rights to delete the report option ""%1"".';es_ES = 'Insufficient rights to delete the report option ""%1"".';es_CO = 'Insufficient rights to delete the report option ""%1"".';tr = 'Insufficient rights to delete the report option ""%1"".';it = 'Insufficient rights to delete the report option ""%1"".';de = 'Insufficient rights to delete the report option ""%1"".'");
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(WarningText, Option.Description);
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	
	If Not Option.Custom Then
		ShowMessageBox(, NStr("ru = 'Cannot delete the predefined report option.'; en = 'Cannot delete the predefined report option.'; pl = 'Cannot delete the predefined report option.';es_ES = 'Cannot delete the predefined report option.';es_CO = 'Cannot delete the predefined report option.';tr = 'Cannot delete the predefined report option.';it = 'Cannot delete the predefined report option.';de = 'Cannot delete the predefined report option.'"));
		Return;
	EndIf;
	
	If Option.DeletionMark Then
		QuestionText = NStr("ru = 'Do you want to clear a deletion mark for ""%1""?'; en = 'Do you want to clear a deletion mark for ""%1""?'; pl = 'Do you want to clear a deletion mark for ""%1""?';es_ES = 'Do you want to clear a deletion mark for ""%1""?';es_CO = 'Do you want to clear a deletion mark for ""%1""?';tr = 'Do you want to clear a deletion mark for ""%1""?';it = 'Do you want to clear a deletion mark for ""%1""?';de = 'Do you want to clear a deletion mark for ""%1""?'");
	Else
		QuestionText = NStr("ru = 'Do you want to mark %1 for deletion?'; en = 'Do you want to mark %1 for deletion?'; pl = 'Do you want to mark %1 for deletion?';es_ES = 'Do you want to mark %1 for deletion?';es_CO = 'Do you want to mark %1 for deletion?';tr = 'Do you want to mark %1 for deletion?';it = 'Do you want to mark %1 for deletion?';de = 'Do you want to mark %1 for deletion?'");
	EndIf;
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionText, Option.Description);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ID", Option.GetID());
	Handler = New NotifyDescription("ReportOptionsBeforeDeleteCompletion", ThisObject, AdditionalParameters);
	
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DialogReturnCode.Yes); 
EndProcedure

&AtClient
Procedure ReportOptionsBeforeDeleteCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		DeleteOptionAtServer(AdditionalParameters.ID);
		ReportsOptionsClient.UpdateOpenForms();
	EndIf;
EndProcedure

&AtClient
Procedure ReportOptionsBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
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

#Region FormCommandHandlers

&AtClient
Procedure Back(Command)
	GoToPage1();
EndProcedure

&AtClient
Procedure Next(Command)
	Package = New Structure;
	Package.Insert("CheckPage1",       True);
	Package.Insert("GoToPage2",       True);
	Package.Insert("FillPage2Server", True);
	Package.Insert("CheckAndWriteServer", False);
	Package.Insert("CloseAfterWrite",       False);
	Package.Insert("CurrentStep", Undefined);
	
	ExecuteBatch(Undefined, Package);
EndProcedure

&AtClient
Procedure Save(Command)
	SaveAndLoad();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptions.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsDescription.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportOptions.Custom");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ReportHiddenColorVariant);
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptions.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsDescription.Name);
	
	FilterGroup = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FilterGroup.GroupType = DataCompositionFilterItemsGroupType.AndGroup;
 
 	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("FullRightsToOptions");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = FilterGroup.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportOptions.CurrentUserAuthor");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.ReportHiddenColorVariant);
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptions.Name);
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportOptionsDescription.Name);
	
 	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportOptions.Order");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 3;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.ReportHiddenColorVariant);
	
	ReportsOptions.SetSubsystemsTreeConditionalAppearance(ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure SetOptionSavingScenarioDeferred()
	SetOptionSavingScenario();
EndProcedure

&AtClient
Procedure ExecuteBatch(Result, Package) Export
	If Not Package.Property("OptionIsNew") Then
		Package.Insert("OptionIsNew", Not ValueIsFilled(OptionRef));
	EndIf;
	
	// Processing the previous step result.
	If Package.CurrentStep = "PromptForOverwrite" Then
		Package.CurrentStep = Undefined;
		If Result = DialogReturnCode.Yes Then
			Package.Insert("PromptForOverwriteConfirmed", True);
		Else
			Return;
		EndIf;
	EndIf;
	
	// Performing the next step.
	If Package.CheckPage1 = True Then
		// Description is not entered.
		If Not ValueIsFilled(DescriptionOption) Then
			ErrorText = NStr("ru = 'Name is not populated'; en = 'Name is not populated'; pl = 'Name is not populated';es_ES = 'Name is not populated';es_CO = 'Name is not populated';tr = 'Name is not populated';it = 'Name is not populated';de = 'Name is not populated'");
			CommonClientServer.MessageToUser(ErrorText, , "DescriptionOption");
			Return;
		EndIf;
		
		// Description of the existing report option is entered.
		If Not Package.OptionIsNew Then
			FoundItems = ReportOptions.FindRows(New Structure("Ref", OptionRef));
			Option = FoundItems[0];
			If Not RightToWriteOption(Option, Context.FullRightsToOptions) Then
				ErrorText = NStr("ru = 'Insufficient rights to change option ""%1"". Select another option or change the name.'; en = 'Insufficient rights to change option ""%1"". Select another option or change the name.'; pl = 'Insufficient rights to change option ""%1"". Select another option or change the name.';es_ES = 'Insufficient rights to change option ""%1"". Select another option or change the name.';es_CO = 'Insufficient rights to change option ""%1"". Select another option or change the name.';tr = 'Insufficient rights to change option ""%1"". Select another option or change the name.';it = 'Insufficient rights to change option ""%1"". Select another option or change the name.';de = 'Insufficient rights to change option ""%1"". Select another option or change the name.'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, DescriptionOption);
				CommonClientServer.MessageToUser(ErrorText, , "DescriptionOption");
				Return;
			EndIf;
			
			If Not Package.Property("PromptForOverwriteConfirmed") Then
				If Option.DeletionMark = True Then
					QuestionText = NStr("ru = 'Report option ""%1"" is marked for deletion. 
					|Replace the report option marked for deletion?'; 
					|en = 'Report option ""%1"" is marked for deletion. 
					|Replace the report option marked for deletion?'; 
					|pl = 'Report option ""%1"" is marked for deletion. 
					|Replace the report option marked for deletion?';
					|es_ES = 'Report option ""%1"" is marked for deletion. 
					|Replace the report option marked for deletion?';
					|es_CO = 'Report option ""%1"" is marked for deletion. 
					|Replace the report option marked for deletion?';
					|tr = 'Report option ""%1"" is marked for deletion. 
					|Replace the report option marked for deletion?';
					|it = 'Report option ""%1"" is marked for deletion. 
					|Replace the report option marked for deletion?';
					|de = 'Report option ""%1"" is marked for deletion. 
					|Replace the report option marked for deletion?'");
					DefaultButton = DialogReturnCode.No;
				Else
					QuestionText = NStr("ru = 'Replace a previously saved option of report ""%1""?'; en = 'Replace a previously saved option of report ""%1""?'; pl = 'Replace a previously saved option of report ""%1""?';es_ES = 'Replace a previously saved option of report ""%1""?';es_CO = 'Replace a previously saved option of report ""%1""?';tr = 'Replace a previously saved option of report ""%1""?';it = 'Replace a previously saved option of report ""%1""?';de = 'Replace a previously saved option of report ""%1""?'");
					DefaultButton = DialogReturnCode.Yes;
				EndIf;
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionText, DescriptionOption);
				Package.CurrentStep = "PromptForOverwrite";
				Handler = New NotifyDescription("ExecuteBatch", ThisObject, Package);
				ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, 60, DefaultButton);
				Return;
			EndIf;
		EndIf;
		
		// Check is completed.
		Package.CheckPage1 = False;
	EndIf;
	
	If Package.GoToPage2 = True Then
		// For external reports, only fill checks are executed without switching the page.
		If Not Context.IsExternal Then
			Items.Pages.CurrentPage = Items.Page2;
			Items.Back.Enabled        = True;
			Items.Next.Enabled        = False;
		EndIf;
		
		// Switch is executed.
		Package.GoToPage2 = False;
	EndIf;
	
	If Package.FillPage2Server = True
		Or Package.CheckAndWriteServer = True Then
		
		ExecutePackageServer(Package);
		
		TreeRows = SubsystemsTree.GetItems();
		For Each TreeRow In TreeRows Do
			Items.SubsystemsTree.Expand(TreeRow.GetID(), True);
		EndDo;
		
		If Package.Cancel = True Then
			GoToPage1();
			Return;
		EndIf;
		
	EndIf;
	
	If Package.CloseAfterWrite = True Then
		ReportsOptionsClient.UpdateOpenForms(, FormName);
		Close(New SettingsChoice(OptionOptionKey));
		Package.CloseAfterWrite = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToPage1()
	Items.Pages.CurrentPage = Items.Page1;
	Items.Back.Enabled        = False;
	Items.Next.Title          = "";
	Items.Next.Enabled        = True;
EndProcedure

&AtClient
Procedure OpenOptionForChange()
	Option = Items.ReportOptions.CurrentData;
	If Option = Undefined Or Not ValueIsFilled(Option.Ref) Then
		Return;
	EndIf;
	If Not RightToConfigureOption(Option, Context.FullRightsToOptions) Then
		WarningText = NStr("ru = 'Insufficient access rights to change option ""%1"".'; en = 'Insufficient access rights to change option ""%1"".'; pl = 'Insufficient access rights to change option ""%1"".';es_ES = 'Insufficient access rights to change option ""%1"".';es_CO = 'Insufficient access rights to change option ""%1"".';tr = 'Insufficient access rights to change option ""%1"".';it = 'Insufficient access rights to change option ""%1"".';de = 'Insufficient access rights to change option ""%1"".'");
		WarningText = StringFunctionsClientServer.SubstituteParametersToString(WarningText, Option.Description);
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	ReportsOptionsClient.ShowReportSettings(Option.Ref);
EndProcedure

&AtClient
Procedure SaveAndLoad()
	Page2Filled = (Items.Pages.CurrentPage = Items.Page2);
	
	Package = New Structure;
	Package.Insert("CheckPage1",       Not Page2Filled);
	Package.Insert("GoToPage2",       Not Page2Filled);
	Package.Insert("FillPage2Server", Not Page2Filled);
	Package.Insert("CheckAndWriteServer", True);
	Package.Insert("CloseAfterWrite",       True);
	Package.Insert("CurrentStep", Undefined);
	
	ExecuteBatch(Undefined, Package);
EndProcedure

&AtClient
Procedure BeginSelectDetailsCompletion(Val EnteredText, Val AdditionalParameters) Export
	
	If EnteredText = Undefined Then
		Return;
	EndIf;	

	OptionDetails = EnteredText;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client and server

&AtClientAtServerNoContext
Function RightToConfigureOption(Option, FullRightsToOptions)
	Return (FullRightsToOptions Or Option.CurrentUserAuthor) AND ValueIsFilled(Option.Ref);
EndFunction

&AtClientAtServerNoContext
Function RightToWriteOption(Option, FullRightsToOptions)
	Return Option.Custom AND RightToConfigureOption(Option, FullRightsToOptions);
EndFunction

&AtClientAtServerNoContext
Function GenerateFreeDescription(Option, ReportOptions)
	OptionNameTemplate = TrimAll(Option.Description) +" - "+ NStr("ru = 'copy'; en = 'copy'; pl = 'copy';es_ES = 'copy';es_CO = 'copy';tr = 'copy';it = 'copy';de = 'copy'");
	
	FreeDescription = OptionNameTemplate;
	FoundItems = ReportOptions.FindRows(New Structure("Description", FreeDescription));
	If FoundItems.Count() = 0 Then
		Return FreeDescription;
	EndIf;
	
	OptionNumber = 1;
	While True Do
		OptionNumber = OptionNumber + 1;
		FreeDescription = OptionNameTemplate +" (" + Format(OptionNumber, "") + ")";
		FoundItems = ReportOptions.FindRows(New Structure("Description", FreeDescription));
		If FoundItems.Count() = 0 Then
			Return FreeDescription;
		EndIf;
	EndDo;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServer
Procedure ExecutePackageServer(Package)
	
	Package.Insert("Cancel", False);
	
	If Package.FillPage2Server = True Then
		If Not Context.IsExternal Then
			RefillSecondPage(Package);
		EndIf;
		Package.FillPage2Server = False;
	EndIf;
	
	If Package.CheckAndWriteServer = True Then
		CheckAndWriteAtServer(Package);
		Package.CheckAndWriteServer = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure DeleteOptionAtServer(ID)
	If ID = Undefined Then
		Return;
	EndIf;
	Option = ReportOptions.FindByID(ID);
	If Option = Undefined Then
		Return;
	EndIf;
	DeletionMark = Not Option.DeletionMark;
	OptionObject = Option.Ref.GetObject();
	OptionObject.SetDeletionMark(DeletionMark);
	Option.DeletionMark = DeletionMark;
	Option.PictureIndex  = ?(DeletionMark, 4, ?(OptionObject.Custom, 3, 5));
EndProcedure

&AtServer
Procedure RefillSecondPage(Package)
	If Package.OptionIsNew Then
		OptionBasis = PrototypeRef;
	Else
		OptionBasis = OptionRef;
	EndIf;
	
	DestinationTree = ReportsOptions.SubsystemsTreeGenerate(ThisObject, OptionBasis);
	ValueToFormAttribute(DestinationTree, "SubsystemsTree");
EndProcedure

&AtServer
Procedure CheckAndWriteAtServer(Package)
	IsNewReportOption = Not ValueIsFilled(OptionRef);
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		If Not IsNewReportOption Then
			LockItem = Lock.Add(Metadata.Catalogs.ReportsOptions.FullName());
			LockItem.SetValue("Ref", OptionRef);
		EndIf;
		Lock.Lock();
		
		If IsNewReportOption AND ReportsOptions.DescriptionIsUsed(Context.ReportRef, OptionRef, DescriptionOption) Then
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '""%1"" is already used, enter another name.'; en = '""%1"" is already used, enter another name.'; pl = '""%1"" is already used, enter another name.';es_ES = '""%1"" is already used, enter another name.';es_CO = '""%1"" is already used, enter another name.';tr = '""%1"" is already used, enter another name.';it = '""%1"" is already used, enter another name.';de = '""%1"" is already used, enter another name.'"), DescriptionOption);
			CommonClientServer.MessageToUser(ErrorText, , "DescriptionOption");
			Package.Cancel = True;
			RollbackTransaction();
			Return;
		EndIf;
		
		If IsNewReportOption Then
			OptionObject = Catalogs.ReportsOptions.CreateItem();
			OptionObject.Report            = Context.ReportRef;
			OptionObject.ReportType        = Context.ReportType;
			OptionObject.VariantKey     = String(New UUID());
			OptionObject.Custom = True;
			OptionObject.Author            = Context.CurrentUser;
			If PrototypePredefined Then
				OptionObject.Parent = PrototypeRef;
			ElsIf TypeOf(PrototypeRef) = Type("CatalogRef.ReportsOptions") AND Not PrototypeRef.IsEmpty() Then
				OptionObject.Parent = Common.ObjectAttributeValue(PrototypeRef, "Parent");
			Else
				OptionObject.FillInParent();
			EndIf;
		Else
			OptionObject = OptionRef.GetObject();
		EndIf;
		
		If Context.IsExternal Then
			OptionObject.Placement.Clear();
		Else
			DestinationTree = FormAttributeToValue("SubsystemsTree", Type("ValueTree"));
			If IsNewReportOption Then
				ChangedSections = DestinationTree.Rows.FindRows(New Structure("Use", 1), True);
			Else
				ChangedSections = DestinationTree.Rows.FindRows(New Structure("Modified", True), True);
			EndIf;
			ReportsOptions.SubsystemsTreeWrite(OptionObject, ChangedSections);
		EndIf;
		
		OptionObject.Description = DescriptionOption;
		OptionObject.Details     = OptionDetails;
		OptionObject.AvailableToAuthorOnly      = OptionForAuthorOnly;
		OptionObject.VisibleByDefault = OptionDefaultVisibility;
		
		OptionObject.Write();
		
		OptionRef       = OptionObject.Ref;
		OptionOptionKey = OptionObject.VariantKey;
		
		If ClearSettings Then
			ReportsOptions.ResetUserSettings(OptionObject.Ref);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure SetOptionSavingScenario()
	NewObjectWillBeWritten = False;
	ExistingObjectWillBeOverwritten = False;
	CannotOverwrite = False;
	
	If DescriptionModified Then 
		Items.ReportOptions.CurrentRow = Context.SearchByDescription.Get(DescriptionOption);
	EndIf;
	
	ID = Items.ReportOptions.CurrentRow;
	Option = ?(ID <> Undefined, ReportOptions.FindByID(ID), Undefined);
	
	If Option = Undefined Then
		NewObjectWillBeWritten = True;
		OptionRef = Undefined;
		OptionDefaultVisibility = True;
		If Not DetailsModified Then
			OptionDetails = "";
		EndIf;
		Items.ReportOptions.CurrentRow = Undefined;
		If Not Context.FullRightsToOptions Then
			OptionForAuthorOnly = True;
		EndIf;
	Else
		RightToWriteOption = RightToWriteOption(Option, Context.FullRightsToOptions);
		If RightToWriteOption Then
			ExistingObjectWillBeOverwritten = True;
			DescriptionModified = False;
			DescriptionOption = Option.Description;
			
			OptionRef = Option.Ref;
			If Context.FullRightsToOptions Then
				OptionForAuthorOnly = Option.AvailableToAuthorOnly;
			Else
				OptionForAuthorOnly = True;
			EndIf;
			OptionDefaultVisibility = Option.VisibleByDefault;
			If Not DetailsModified Then
				OptionDetails = Option.Details;
			EndIf;
		Else
			If DescriptionModified Then
				CannotOverwrite = True;
				Items.ReportOptions.CurrentRow = Undefined;
			Else
				NewObjectWillBeWritten = True;
				DescriptionOption = GenerateFreeDescription(Option, ReportOptions);
			EndIf;
			
			OptionRef = Undefined;
			OptionForAuthorOnly      = True;
			OptionDefaultVisibility = True;
			If Not DetailsModified Then
				OptionDetails = "";
			EndIf;
		EndIf;
	EndIf;
	
	Available = ?(OptionForAuthorOnly, "AuthorOnly", "AllUsers");
	
	If NewObjectWillBeWritten Then
		Items.WhatIsNext.CurrentPage = Items.New;
		Items.ClearSettings.Visible = False;
		Items.Next.Enabled     = True;
		Items.Save.Enabled = True;
	ElsIf ExistingObjectWillBeOverwritten Then
		Items.WhatIsNext.CurrentPage = Items.Overwrite;
		Items.ClearSettings.Visible = True;
		Items.Next.Enabled     = True;
		Items.Save.Enabled = True;
	ElsIf CannotOverwrite Then
		Items.WhatIsNext.CurrentPage = Items.CannotOverwrite;
		Items.ClearSettings.Visible = False;
		Items.Next.Enabled     = False;
		Items.Save.Enabled = False;
	EndIf;
EndProcedure

&AtServer
Procedure FillOptionsList(UpdateForm)
	
	CurrentOptionKey = PrototypeKey;
	
	// Changing to the "before refilling" option key.
	CurrentRowID = Items.ReportOptions.CurrentRow;
	If CurrentRowID <> Undefined Then
		CurrentRow = ReportOptions.FindByID(CurrentRowID);
		If CurrentRow <> Undefined Then
			CurrentOptionKey = CurrentRow.VariantKey;
		EndIf;
	EndIf;
	
	ReportOptions.Clear();
	
	QueryText =
	"SELECT ALLOWED
	|	ReportsOptions.Ref AS Ref,
	|	ReportsOptions.Custom AS Custom,
	|	ReportsOptions.Description AS Description,
	|	ReportsOptions.Author AS Author,
	|	ReportsOptions.Details AS Details,
	|	ReportsOptions.ReportType AS Type,
	|	ReportsOptions.VariantKey AS VariantKey,
	|	ReportsOptions.AvailableToAuthorOnly AS AvailableToAuthorOnly,
	|	ReportsOptions.VisibleByDefault AS VisibleByDefault,
	|	ReportsOptions.DeletionMark AS DeletionMark,
	|	CASE
	|		WHEN ReportsOptions.Author = &CurrentUser
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS CurrentUserAuthor,
	|	CASE
	|		WHEN ReportsOptions.DeletionMark
	|			THEN 4
	|		WHEN ReportsOptions.Custom
	|			THEN 3
	|		ELSE 5
	|	END AS PictureIndex,
	|	CASE
	|		WHEN ReportsOptions.DeletionMark
	|			THEN 3
	|		WHEN ReportsOptions.Custom
	|			THEN 2
	|		ELSE 1
	|	END AS Order
	|FROM
	|	Catalog.ReportsOptions AS ReportsOptions
	|WHERE
	|	ReportsOptions.Report = &Report
	|	AND (ReportsOptions.DeletionMark = FALSE
	|		OR ReportsOptions.Custom = TRUE)
	|	AND (ReportsOptions.AvailableToAuthorOnly = FALSE
	|		OR ReportsOptions.Author = &CurrentUser
	|		OR ReportsOptions.VariantKey = &PrototypeKey
	|		OR ReportsOptions.VariantKey = &CurrentOptionKey)
	|	AND NOT ReportsOptions.PredefinedVariant IN (&DIsabledApplicationOptions)";
	
	Query = New Query;
	Query.SetParameter("Report", Context.ReportRef);
	Query.SetParameter("PrototypeKey", PrototypeKey);
	Query.SetParameter("CurrentOptionKey", CurrentOptionKey);
	Query.SetParameter("CurrentUser", Context.CurrentUser);
	Query.SetParameter("DIsabledApplicationOptions", ReportsOptionsCached.DIsabledApplicationOptions());
	
	Query.Text = QueryText;
	
	ValueTable = Query.Execute().Unload();
	
	ReportOptions.Load(ValueTable);
	
	// Add predefined options of an external report.
	If Context.IsExternal Then
		Try
			ReportObject = ExternalReports.Create(Context.ReportName);
		Except
			ReportsOptions.WriteToLog(EventLogLevel.Error,
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Cannot receive a list of predefined options
						| of external report ""%1"":'; 
						|en = 'Cannot receive a list of predefined options
						| of external report ""%1"":'; 
						|pl = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|es_ES = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|es_CO = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|tr = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|it = 'Cannot receive a list of predefined options
						| of external report ""%1"":';
						|de = 'Cannot receive a list of predefined options
						| of external report ""%1"":'"),
					Context.ReportRef)
				+ Chars.LF
				+ DetailErrorDescription(ErrorInfo()));
			Return;
		EndTry;
		
		If ReportObject.DataCompositionSchema = Undefined Then
			Return;
		EndIf;
		
		For Each DCSettingsOption In ReportObject.DataCompositionSchema.SettingVariants Do
			Option = ReportOptions.Add();
			Option.Custom = False;
			Option.Description = DCSettingsOption.Presentation;
			Option.VariantKey = DCSettingsOption.Name;
			Option.AvailableToAuthorOnly = False;
			Option.CurrentUserAuthor = False;
			Option.PictureIndex = 5;
		EndDo;
	EndIf;
	
	ReportOptions.Sort("Description Asc");
	
	Context.SearchByDescription = New Map;
	For Each Option In ReportOptions Do
		ID = Option.GetID();
		Context.SearchByDescription.Insert(Option.Description, ID);
		If Option.VariantKey = PrototypeKey Then
			PrototypeRef           = Option.Ref;
			PrototypePredefined = Not Option.Custom;
		EndIf;
		If Option.VariantKey = CurrentOptionKey Then
			Items.ReportOptions.CurrentRow = ID;
		EndIf;
	EndDo;
	
	SetOptionSavingScenario();
EndProcedure

&AtServer
Procedure DeleteSecondLineInTitle(TitleText)
	TitleText = Left(TitleText, StrFind(TitleText, Chars.LF)-1);
EndProcedure

#EndRegion
