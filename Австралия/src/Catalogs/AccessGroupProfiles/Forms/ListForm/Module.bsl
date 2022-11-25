
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "SelectionPick");
	EndIf;
	
	If Parameters.ChoiceMode Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
		
		// Hiding the Administrator profile.
		CommonClientServer.SetDynamicListFilterItem(
			List, "Ref", Catalogs.AccessGroupProfiles.Administrator,
			DataCompositionComparisonType.NotEqual, , True);
		
		Items.List.ChoiceFoldersAndItems = Parameters.ChoiceFoldersAndItems;
		
		AutoTitle = False;
		If Parameters.CloseOnChoice = False Then
			// Pick mode.
			Items.List.MultipleChoice = True;
			Items.List.SelectionMode = TableSelectionMode.MultiRow;
			
			Title = NStr("ru = 'Подбор профилей групп доступа'; en = 'Pick access group profiles'; pl = 'Wybór profili grupy dostępu';es_ES = 'Elegir los perfiles del grupo de acceso';es_CO = 'Elegir los perfiles del grupo de acceso';tr = 'Erişim grubu profillerini seç';it = 'Prendi profili gruppo accesso';de = 'Wählen Sie Zugriffsgruppenprofile aus'");
		Else
			Title = NStr("ru = 'Выбор профиля групп доступа'; en = 'Select access group profile'; pl = 'Wybierz profil grupy dostępu';es_ES = 'Seleccionar un perfil del grupo de acceso';es_CO = 'Seleccionar un perfil del grupo de acceso';tr = 'Erişim grubu profilini seç';it = 'Seleziona profilo gruppo di accesso';de = 'Wählen Sie ein Zugriffsgruppenprofil aus'");
		EndIf;
	Else
		Items.List.ChoiceMode = False;
	EndIf;
	
	If Parameters.Property("ProfilesWithRolesMarkedForDeletion") Then
		ShowProfiles = "OutdatedProfiles";
	Else
		ShowProfiles = "AllProfiles";
	EndIf;
	
	If Not Parameters.ChoiceMode Then
		SetFilter();
	Else
		Items.ShowProfiles.Visible = False;
	EndIf;
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormControlItemsEventHandlers

&AtClient
Procedure ShowProfilesOnChange(Item)
	
	SetFilter();
	
EndProcedure

&AtClient
Procedure UsersKindStartChoice(Item, ChoiceData, StandardProcessing)
	
	NotifyDescription = New NotifyDescription("AfterAssignmentChoice", ThisObject);
	
	UsersInternalClient.SelectPurpose(ThisObject,
		NStr("ru = 'Выбор назначения профилей'; en = 'Select profile assignment'; pl = 'Wybór przydziału profili';es_ES = 'Selección de asignación de perfiles';es_CO = 'Selección de asignación de perfiles';tr = 'Profil amaçlarının seçimi';it = 'Seleziona incarico profilo';de = 'Auswahl der Profilzuordnung'"), True, True, NotifyDescription);
	
EndProcedure

&AtClient
Procedure UsersKindClear(Item, StandardProcessing)
	
	CommonClientServer.SetDynamicListFilterItem(
		List, "Ref.Purpose.UsersType", , , , False);
		
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListOnChange(Item)
	
	ListOnChangeAtServer();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Update(Command)
	
	UpdateAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateAtServer()
	
	SetFilter();
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure SetFilter()
	
	If ShowProfiles = "OutdatedProfiles" Then
		CommonClientServer.SetDynamicListFilterItem(List,
			"Ref",
			Catalogs.AccessGroupProfiles.IncompatibleAccessGroupsProfiles(),
			DataCompositionComparisonType.InList, , True);
	Else
		CommonClientServer.SetDynamicListFilterItem(List,
			"Ref", , , , False);
	EndIf;
	
	If ShowProfiles = "SuppliedProfiles" Then
		CommonClientServer.SetDynamicListFilterItem(List,
			"Ref.SuppliedDataID",
			New UUID("00000000-0000-0000-0000-000000000000"),
			DataCompositionComparisonType.NotEqual, , True);
		
	ElsIf ShowProfiles = "UnsuppliedProfiles" Then
		CommonClientServer.SetDynamicListFilterItem(List,
			"Ref.SuppliedDataID",
			New UUID("00000000-0000-0000-0000-000000000000"),
			DataCompositionComparisonType.Equal, , True);
	Else
		CommonClientServer.SetDynamicListFilterItem(List,
			"Ref.SuppliedDataID", , , , False);
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterAssignmentChoice(TypesArray, AdditionalParameters) Export
	
	If TypesArray.Count() <> 0 Then
		CommonClientServer.SetDynamicListFilterItem(List,
			"Ref.Purpose.UsersType",
			TypesArray,
			DataCompositionComparisonType.InList, , True);
	Else
		CommonClientServer.SetDynamicListFilterItem(
			List, "Ref.Purpose.UsersType", , , , False);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ListOnChangeAtServer()
	
	AccessManagementInternal.AfterChangeRightsSettingsInForm();
	
EndProcedure

#EndRegion
