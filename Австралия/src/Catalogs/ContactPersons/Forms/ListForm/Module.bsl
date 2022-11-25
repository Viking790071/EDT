
#Region FormEventHadlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then
		Return; // Return if the form for analysis is received..
	EndIf;
	
	Parameters.Filter.Property("Owner", CounterpartyOwner);
	
	If ValueIsFilled(CounterpartyOwner) Then
		// Context opening of the form with the selection by the counterparty
	
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Contact persons %1'; ru = 'Контактные лица %1';pl = 'Osoby kontaktowe %1';es_ES = 'Personas de contacto %1';es_CO = 'Personas de contacto %1';tr = 'İlgili kişiler %1';it = 'Persone di contatto %1';de = 'Ansprechpartner %1'"),
			CounterpartyOwner);
		
		List.Parameters.SetParameterValue("MainCounterpartyContactPerson",
			Common.ObjectAttributeValue(CounterpartyOwner, "ContactPerson"));
		
	Else
		// Opening in common mode
		
		Items.Owner.Visible		= True;
		Items.MoveUp.Visible	= False;
		Items.MoveDown.Visible	= False;
		List.Parameters.SetParameterValue("MainCounterpartyContactPerson", Undefined);
		
	EndIf;
	
	Items.UseAsMain.Visible = AccessRight("Edit", Metadata.Catalogs.Counterparties);
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Invalid",
		False,
		,
		,
		Not Items.ShowInvalid.Check);
	
	// Establish the settings form for the case of the opening of the choice mode
	Items.List.ChoiceMode = Parameters.ChoiceMode;
	Items.List.MultipleChoice = ?(Parameters.CloseOnChoice = Undefined, False, Not Parameters.CloseOnChoice);
	If Parameters.ChoiceMode Then
		PurposeUseKey = "ChoicePick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	Else
		PurposeUseKey = "List";
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region FormItemsEventHadlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Items.List.CurrentRow) <> Type("DynamicListGroupRow")
		AND Items.List.CurrentData <> Undefined Then
		
		Items.UseAsMain.Enabled = Not Items.List.CurrentData.IsMainContactPerson;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure UseAsMain(Command)
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicListGroupRow")
		Or Items.List.CurrentData = Undefined
		Or Items.List.CurrentData.IsMainContactPerson Then
		
		Return;
	EndIf;
	
	NewMainContactPerson = Items.List.CurrentData.Ref;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Counterparty", Items.List.CurrentData.Owner);
	ParametersStructure.Insert("NewMainContactPerson", NewMainContactPerson);
	
	WriteMainContactPerson(ParametersStructure);
	
	// Update dynamical list
	If ValueIsFilled(CounterpartyOwner) Then
		List.Parameters.SetParameterValue("MainCounterpartyContactPerson", NewMainContactPerson);
	Else
		Items.List.Refresh();;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowInvalid(Command)
	
	Items.ShowInvalid.Check = Not Items.ShowInvalid.Check;
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Invalid",
		False,
		,
		,
		Not Items.ShowInvalid.Check);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions
	
&AtServer
Procedure SetConditionalAppearance()
	
	// 1. Invalid contact distinguish gray
	NewConditionalAppearance = List.SettingsComposer.FixedSettings.ConditionalAppearance.Items.Add();
	
	Appearance = NewConditionalAppearance.Appearance.Items.Find("TextColor");
	Appearance.Value 	= StyleColors.UnavailableTabularSectionTextColor;
	Appearance.Use		= True;
	
	Filter = NewConditionalAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	Filter.ComparisonType	= DataCompositionComparisonType.Equal;
	Filter.Use				= True;
	Filter.LeftValue 		= New DataCompositionField("Invalid");
	Filter.RightValue 		= True;
	
EndProcedure

&AtServerNoContext
Procedure WriteMainContactPerson(ParametersStructure)
	
	CounterpartyObject = ParametersStructure.Counterparty.GetObject();
	CounterpartySuccesfullyLocked = True;
	
	Try
		CounterpartyObject.Lock();
	Except
		
		CounterpartySuccesfullyLocked = False;
		
		MessageText = StrTemplate(
			NStr("en = 'Could not be locked %1: %2, for editing main contact person, because:
			     |%3'; 
			     |ru = 'Не удалось заблокировать %1: %2, для изменения основного контактного лица, по причине:
			     |%3';
			     |pl = 'Nie można zablokować %1:%2, do edycji głównej osoby kontaktowej, ponieważ:
			     |%3';
			     |es_ES = 'No puede bloquearse %1: %2, para edición de la principal persona de contacto, porque:
			     |%3';
			     |es_CO = 'No puede bloquearse %1: %2, para edición de la principal persona de contacto, porque:
			     |%3';
			     |tr = 'Kilitlenemedi %1: %2, ana ilgili kişinin düzenlenmesi için, çünkü:
			     |%3';
			     |it = 'Non può essere bloccato %1: %2, per la modifica del principale referente, perché:
			     |%3';
			     |de = 'Konnte nicht gesperrt werden %1: %2, zur Bearbeitung der Hauptansprechpartner, weil:
			     |%3'", Metadata.DefaultLanguage.LanguageCode), 
				ParametersStructure.Counterparty.Metadata().ObjectPresentation, DetailErrorDescription(ErrorInfo()));
		WriteLogEvent(MessageText, EventLogLevel.Warning,, CounterpartyObject, ErrorDescription());
		
	EndTry;
	
	// If lockig was successful edit bank account by default of counterparty
	If CounterpartySuccesfullyLocked Then
		CounterpartyObject.ContactPerson = ParametersStructure.NewMainContactPerson;
		CounterpartyObject.Write();
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers
	
&AtClient
Procedure MoveUp(Command)
	
	MoveAtServer("Up");
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	MoveAtServer("Down");
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure MoveAtServer(Direction)
	ItemsOrderSetupInternal.MoveItem(Items.List, Items.List.CurrentRow, Direction);
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.SearchAndDeleteDuplicates

&AtClient
Procedure MergeSelected(Command)
	FindAndDeleteDuplicatesDuplicatesClient.MergeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure ShowUsage(Command)
	FindAndDeleteDuplicatesDuplicatesClient.ShowUsageInstances(Items.List);
EndProcedure

// End StandardSubsystems.SearchAndDeleteDuplicates

#EndRegion

#EndRegion