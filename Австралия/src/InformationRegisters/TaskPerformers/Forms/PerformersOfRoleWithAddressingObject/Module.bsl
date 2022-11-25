///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	Role = Parameters.Role;
	SetRoleAvailability(Role);
	MainAddressingObject = Parameters.MainAddressingObject;
	If MainAddressingObject = Undefined Or MainAddressingObject = "" Then
		Items.AdditionalAddressingObject.Visible = False;
		Items.List.Header = False;
		Items.MainAddressingObject.Visible = False;
	Else
		Items.MainAddressingObject.Title = MainAddressingObject.Metadata().ObjectPresentation;
		AdditionalAddressingObject = Parameters.Role.AdditionalAddressingObjectTypes;
		Items.AdditionalAddressingObject.Visible = NOT AdditionalAddressingObject.IsEmpty();
		Items.AdditionalAddressingObject.Title = AdditionalAddressingObject.Description;
		AdditionalAddressingObjectTypes = AdditionalAddressingObject.ValueType;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Исполнители роли ""%1""'; en = 'Assignees for role: %1'; pl = 'Wykonawcy dla roli: %1';es_ES = 'Ejecutores para el rol:%1';es_CO = 'Ejecutores para el rol:%1';tr = 'Role atananlar: %1';it = 'Assegnatari per il ruolo: %1';de = 'Aufgabenempfänger für die Rolle: %1'"), Role);
	
	SetRecordSetFilter();
	
	
EndProcedure

&AtServer
Procedure SetRoleAvailability(Role)
	
	RoleIsAvailableToExternalUsers = GetFunctionalOption("UseExternalUsers");
	If Not RoleIsAvailableToExternalUsers Then
		RoleIsAvailableToUsers = True;
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	AssigneeRolesAssignment.UsersType
		|FROM
		|	Catalog.PerformerRoles.Purpose AS AssigneeRolesAssignment
		|WHERE
		|	AssigneeRolesAssignment.Ref = &Ref";
	
	Query.SetParameter("Ref", Role);
	
	QueryResult = Query.Execute();
	ExternalUsersAreNotAssignedForRole = True;
	
	If NOT QueryResult.IsEmpty() Then
		DetailedRecordsSelection = QueryResult.Select();
		
		RoleIsAvailableToUsers = False;
		
		While DetailedRecordsSelection.Next() Do
			Purpose.Add(DetailedRecordsSelection.UsersType);
			If DetailedRecordsSelection.UsersType = Catalogs.Users.EmptyRef() Then
				RoleIsAvailableToUsers = True;
			Else
				ExternalUsersAreNotAssignedForRole = False;
			EndIf;
		
		EndDo;
	Else
		RoleIsAvailableToUsers = True;
	EndIf;
	
	If ExternalUsersAreNotAssignedForRole Then
		RoleIsAvailableToExternalUsers = False;
	EndIf;
	
	If RoleIsAvailableToExternalUsers AND RoleIsAvailableToUsers Then
		Items.Performer.ChooseType = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	SetRecordSetFilter();

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure SetRecordSetFilter()
	
	RecordSetObject = FormAttributeToValue("RecordSet");
	RecordSetObject.Filter.MainAddressingObject.Set(MainAddressingObject);
	RecordSetObject.Filter.PerformerRole.Set(Role);
	RecordSetObject.Read();
	ValueToFormAttribute(RecordSetObject, "RecordSet");
	For each Record In RecordSet Do
		Record.Invalid = Record.Performer.Invalid;
	EndDo;

EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	For each LinePerformer In RecordSet Do
		If NOT ValueIsFilled(LinePerformer.Performer) Then
			ShowMessageBox(, NStr("ru = 'Необходимо указать исполнителей.'; en = 'Specify assignees.'; pl = 'Określ wykonawców.';es_ES = 'Especifique los ejecutores.';es_CO = 'Especifique los ejecutores.';tr = 'Atananları belirleyin';it = 'È necessario specificare l''esecutore.';de = 'Aufgabenempfänger beschreiben.'"));
			Cancel = True;
		EndIf;
	EndDo;
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_RoleAddressing", WriteParameters, RecordSet);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AfterWriteAtServer(ThisObject, CurrentObject, WriteParameters);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	If Role <> Undefined Then
		Item.CurrentData.PerformerRole = Role;
	EndIf;
	If MainAddressingObject <> Undefined Then
		Item.CurrentData.MainAddressingObject = MainAddressingObject;
	EndIf;
	
	Item.CurrentData.Invalid = DetermineUsersValidity(Item.CurrentData.Performer);
	
EndProcedure

&AtClient
Procedure ListOnStartEdit(Item, NewRow, Clone)
	
	If Items.AdditionalAddressingObject.Visible Then
		Items.AdditionalAddressingObject.TypeRestriction = AdditionalAddressingObjectTypes;
	EndIf;
	
	If Item.CurrentData <> Undefined AND NOT ValueIsFilled(Item.CurrentData.Performer) Then
		If RoleIsAvailableToUsers AND NOT RoleIsAvailableToExternalUsers Then
			Item.CurrentData.Performer = PredefinedValue("Catalog.Users.EmptyRef");
		ElsIf NOT RoleIsAvailableToUsers AND RoleIsAvailableToExternalUsers Then
			Item.CurrentData.Performer = PredefinedValue("Catalog.ExternalUsers.EmptyRef");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessingList(Item, ValueSelected, StandardProcessing)
	
	UsersList = DetermineUsersValidity(ValueSelected);
	For each Value In UsersList Do
		
		If RecordSet.FindRows(New Structure("Performer", Value.Key)).Count() > 0 Then
			Continue;
		EndIf;
			
		Performer = RecordSet.Add();
		
		Performer.Performer = Value.Key;
		Performer.Invalid = Value.Value;
		If Role <> Undefined Then
			Performer.PerformerRole = Role;
		EndIf;
		If MainAddressingObject <> Undefined Then
			Performer.MainAddressingObject = MainAddressingObject;
		EndIf;
		Modified = True;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtServerNoContext
Function DetermineUsersValidity(UsersList)
	
	If ValueIsFilled(UsersList) Then
		If TypeOf(UsersList) = Type("Array") Then
			Result = New Map;
			For each Value In UsersList Do
				Result.Insert(Value, Value.Invalid);
			EndDo;
			Return Result;
		Else
			Return UsersList.Invalid;
		EndIf;
	EndIf;
	
	Return False;
	
EndFunction

&AtClient
Procedure Select(Command)
	
	If RoleIsAvailableToExternalUsers AND RoleIsAvailableToUsers Then
		Choice = New ValueList;
		Choice.Add("ExternalUser", NStr("ru = 'Внешний пользователь'; en = 'External user'; pl = 'Użytkownik zewnętrzny';es_ES = 'Usuario externo';es_CO = 'Usuario externo';tr = 'Harici kullanıcı';it = 'Utente esterno';de = 'Externer Benutzer'"));
		Choice.Add("User", NStr("ru = 'Пользователь'; en = 'User'; pl = 'Użytkownik';es_ES = 'Usuario';es_CO = 'Usuario';tr = 'Kullanıcı';it = 'Utente';de = 'Benutzer'"));
		NotifyDescription = New NotifyDescription("AfterUserTypeChoice", ThisObject);
		Choice.ShowChooseItem(NotifyDescription, NStr("ru = 'Выберите тип пользователя'; en = 'Select user type'; pl = 'Wybierz rodzaj użytkownika';es_ES = 'Seleccione el tipo de usuario';es_CO = 'Seleccione el tipo de usuario';tr = 'Kullanıcı türünü seçin';it = 'Selezionate il tipo di utente';de = 'Auswahl des Benutzertyps'"));
	ElsIf RoleIsAvailableToUsers Then
		OpenSelectionForm("User");
	ElsIf RoleIsAvailableToExternalUsers Then
		OpenSelectionForm("ExternalUser");
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure AfterUserTypeChoice(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		OpenSelectionForm(Result.Value);
	EndIf;
EndProcedure

&AtClient
Procedure OpenSelectionForm(OpeningMode)
	
	ChoiceFormParameters = New Structure;
	ChoiceFormParameters.Insert("ChoiceFoldersAndItems", FoldersAndItemsUse.FoldersAndItems);
	ChoiceFormParameters.Insert("CloseOnChoice", False);
	ChoiceFormParameters.Insert("CloseOnOwnerClose", True);
	ChoiceFormParameters.Insert("MultipleChoice", True);
	ChoiceFormParameters.Insert("ChoiceMode", True);
	ChoiceFormParameters.Insert("SelectFolders", False);
	ChoiceFormParameters.Insert("UsersGroupsSelection", False);
		
	If OpeningMode = "ExternalUser" Then
		ChoiceFormParameters.Insert("Purpose", Purpose.UnloadValues());
		OpenForm("Catalog.ExternalUsers.ChoiceForm", ChoiceFormParameters, Items.List);
	Else
		OpenForm("Catalog.Users.ChoiceForm", ChoiceFormParameters, Items.List);
	EndIf;

EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	Item = ConditionalAppearance.Items.Add();
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField("Performer");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("RecordSet.Invalid");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", Metadata.StyleItems.InaccessibleCellTextColor.Value);
	
EndProcedure

#EndRegion
