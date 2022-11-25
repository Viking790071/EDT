
#Region Variables

&AtClient
Var WriteParametersBeforeWriteFollowUp;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ProcessRolesInterface("FillRoles", Object.Roles);
	ProcessRolesInterface("SetUpRoleInterfaceOnFormCreate", ValueIsFilled(Object.Ref));
	
	// Preparing auxiliary data.
	AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm(ThisObject, True);
	
	// Making the properties always visible.
	
	// Determining if the access restrictions must be set.
	If NOT AccessManagement.LimitAccessAtRecordLevel() Then
		Items.AccessKindsAndValues.Visible = False;
	EndIf;
	
	// Determining if the form item editing is possible.
	WithoutEditingSuppliedValues = ReadOnly
		OR NOT Object.Ref.IsEmpty() AND Catalogs.AccessGroupProfiles.ProfileChangeProhibition(Object);
		
	DataSeparationEnabled = Common.DataSeparationEnabled();
	If Object.Ref = Catalogs.AccessGroupProfiles.Administrator
	   AND Not Users.IsFullUser(, Not DataSeparationEnabled) Then
		ReadOnly = True;
	EndIf;
	
	Items.Description.ReadOnly = WithoutEditingSuppliedValues;
	
	// Setting up access kind editing.
	Items.AccessKinds.ReadOnly     = WithoutEditingSuppliedValues;
	Items.AccessValues.ReadOnly = WithoutEditingSuppliedValues;
	Items.SelectPurpose.Enabled = Not WithoutEditingSuppliedValues;
	
	ProcessRolesInterface("SetRolesReadOnly", WithoutEditingSuppliedValues);
	
	SetAvailabilityToDescribeAndRestoreSuppliedProfile();
	
	ProcedureExecutedOnCreateAtServer = True;
	
	UsersInternal.UpdateAssignmentOnCreateAtServer(ThisObject);
	
	If Common.IsStandaloneWorkplace() Then
		ReadOnly = True;
	EndIf;
	
	UsersInternalClientServer.SetWriteAndCloseButtonAvailability(ThisObject);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If NOT ProcedureExecutedOnCreateAtServer Then
		Return;
	EndIf;
	
	ProcessRolesInterface("FillRoles", Object.Roles);
	ProcessRolesInterface("SetUpRoleInterfaceOnReadAtServer", True);
	
	AccessManagementInternal.OnRereadAtServerAllowedValuesEditForm(
		ThisObject, CurrentObject);
	
	UpdateProfileAccessGroups = False;
	
	SetAvailabilityToDescribeAndRestoreSuppliedProfile(CurrentObject);
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	ProfileFillingCheckRequired = NOT WriteParameters.Property(
		"ProfileAccessGroupsUpdateResponseReceived");
	
	If ValueIsFilled(Object.Ref)
	   AND ProfileAccessGroupsUpdateRequired
	   AND NOT WriteParameters.Property("ProfileAccessGroupsUpdateResponseReceived") Then
		
		Cancel = True;
		WriteParametersBeforeWriteFollowUp = WriteParameters;
		AttachIdleHandler("BeforeWriteFollowUpIdleHandler", 0.1, True);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// Filling object roles from the collection.
	CurrentObject.Roles.Clear();
	For each Row In RolesCollection Do
		CurrentObject.Roles.Add().Role = Common.MetadataObjectID(
			"Role." + Row.Role);
	EndDo;
	
	If WriteParameters.Property("UpdateProfileAccessGroups") Then
		CurrentObject.AdditionalProperties.Insert("UpdateProfileAccessGroups");
	EndIf;
	
	AccessManagementInternal.BeforeWriteAtServerAllowedValuesEditForm(
		ThisObject, CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If CurrentObject.AdditionalProperties.Property(
	         "PersonalAccessGroupsWithUpdatedDescription") Then
		
		WriteParameters.Insert(
			"PersonalAccessGroupsWithUpdatedDescription",
			CurrentObject.AdditionalProperties.PersonalAccessGroupsWithUpdatedDescription);
	EndIf;
	
	AccessManagementInternal.AfterWriteAtServerAllowedValuesEditForm(
		ThisObject, CurrentObject, WriteParameters);
	
	SetAvailabilityToDescribeAndRestoreSuppliedProfile(CurrentObject);
	
	AccessManagementInternal.AfterChangeRightsSettingsInForm();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	ObjectWasWritten = True;
	ProfileAccessGroupsUpdateRequired = False;
	
	Notify("Write_AccessGroupProfiles", New Structure, Object.Ref);
	
	If WriteParameters.Property("PersonalAccessGroupsWithUpdatedDescription") Then
		NotifyChanged(Type("CatalogRef.AccessGroups"));
		
		For each PersonalAccessGroup In WriteParameters.PersonalAccessGroupsWithUpdatedDescription Do
			Notify("Write_AccessGroups", New Structure, PersonalAccessGroup);
		EndDo;
	EndIf;
	
	If WriteParameters.Property("WriteAndClose") Then
		AttachIdleHandler("CloseForm", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	If NOT ProfileFillingCheckRequired Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	VerifiedObjectAttributes = New Array;
	Errors = Undefined;
	
	// Checking whether the metadata contains roles.
	VerifiedObjectAttributes.Add("Roles.Role");
	If Not Items.Roles.ReadOnly Then
		TreeItems = Roles.GetItems();
		For Each Row In TreeItems Do
			If Not Row.Check Then
				Continue;
			EndIf;
			If Row.IsNonExistingRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" не найдена в метаданных.'; en = 'Role ""%1"" is not found in the metadata.'; pl = 'Rola ""%1"" nie została znaleziona w metadanych.';es_ES = 'Rol ""%1"" no se ha encontrado en los metadatos.';es_CO = 'Rol ""%1"" no se ha encontrado en los metadatos.';tr = '""%1"" rolü meta veride bulunamadı.';it = 'Il ruolo ""%1"" non è stato trovato nei metadata.';de = 'Die Rolle ""%1"" wurde in den Metadaten nicht gefunden.'"), Row.Synonym),
					"Roles",
					TreeItems.IndexOf(Row),
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" в строке %%1 не найдена в метаданных.'; en = 'Role ""%1"" in line #%%1 is not found in the metadata.'; pl = 'Rola ""%1"" w wierszu %%1 nie została znaleziona w metadanych.';es_ES = 'El rol ""%1"" en la línea %%1 no se ha encontrado en los metadatos.';es_CO = 'El rol ""%1"" en la línea %%1 no se ha encontrado en los metadatos.';tr = '%%1 Satırdaki rol %1 meta veride bulunamadı.';it = 'Il ruolo ""%1"" nella linea #%%1 non è stato trovato nei metadati.';de = 'Die Rolle ""%1"" in der %%1-Zeile wurde in den Metadaten nicht gefunden.'"), Row.Synonym));
			EndIf;
			If Row.IsUnavailableRole Then
				CommonClientServer.AddUserError(Errors,
					"Roles[%1].RolesSynonym",
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" недоступна для назначения профиля.'; en = 'Role ""%1"" is not available for profile assignment.'; pl = 'Do roli ""%1"" nie można przydzielić profilu.';es_ES = 'El rol ""%1"" no está disponible para asignar el perfil.';es_CO = 'El rol ""%1"" no está disponible para asignar el perfil.';tr = '""%1"" rolü profil atamak için kullanılamaz.';it = 'Il ruolo ""%1"" non è disponibile per l''assegnamento del profilo.';de = 'Die Rolle ""%1"" ist für die Zuordnung eines Profils nicht verfügbar.'"), Row.Synonym),
					"Roles",
					TreeItems.IndexOf(Row),
					StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль ""%1"" в строке %%1 недоступна для назначения профиля.'; en = 'Role ""%1"" in line %%1 is not available for profile assignment.'; pl = 'Do roli ""%1"" w wierszu %%1 nie można przydzielić profilu.';es_ES = 'El rol ""%1"" en la línea %%1 no está disponible para asignar el perfil.';es_CO = 'El rol ""%1"" en la línea %%1 no está disponible para asignar el perfil.';tr = '%%1 satırındaki ""%1"" rolü profil atamak için kullanılamaz.';it = 'Il ruolo ""%1"" nella line %%1 non è disponibile per l''assegnamento del profilo.';de = 'Die Rolle ""%1"" in der Zeile %%1 ist für die Zuordnung eines Profils nicht verfügbar.'"), Row.Synonym));
			EndIf;
		EndDo;
	EndIf;
	
	// Checking for blank and duplicate access kinds and values.
	AccessManagementInternalClientServer.ProcessingOfCheckOfFillingAtServerAllowedValuesEditForm(
		ThisObject, Cancel, VerifiedObjectAttributes, Errors);
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	CheckedAttributes.Delete(CheckedAttributes.Find("Object"));
	CurrentObject = FormAttributeToValue("Object");
	
	CurrentObject.AdditionalProperties.Insert("VerifiedObjectAttributes",
		VerifiedObjectAttributes);
	
	If NOT CurrentObject.CheckFilling() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ProcessRolesInterface("SetUpRoleInterfaceOnLoadSettings", Settings);
	
EndProcedure

#EndRegion

#Region AccessKindsFormTableItemsEventHandlers

&AtClient
Procedure AccessKindsOnChange(Item)
	
	ProfileAccessGroupsUpdateRequired = True;
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateRow(Item)
	
	AccessManagementInternalClient.AccessKindsOnActivateRow(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	AccessManagementInternalClient.AccessKindsBeforeAddRow(
		ThisObject, Item, Cancel, Clone, Parent, IsFolder);
	
EndProcedure

&AtClient
Procedure AccessKindsBeforeDeleteRow(Item, Cancel)
	
	AccessManagementInternalClient.AccessKindsBeforeDeleteRow(
		ThisObject, Item, Cancel);
	
EndProcedure

&AtClient
Procedure AccessKindsOnStartEdit(Item, NewRow, Clone)
	
	AccessManagementInternalClient.AccessKindsOnStartEdit(
		ThisObject, Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure AccessKindsOnEndEdit(Item, NewRow, CancelEdit)
	
	AccessManagementInternalClient.AccessKindsOnEndEdit(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the AccessKindPresentation item of the AccessKinds form table.

&AtClient
Procedure AccessKindsAccessKindPresentationOnChange(Item)
	
	AccessManagementInternalClient.AccessKindsAccessKindPresentationOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsAccessKindPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementInternalClient.AccessKindsAccessKindPresentationChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
		
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Event handlers of the AllAllowedPresentation item of the AccessKinds form table.

&AtClient
Procedure AccessKindsAllAllowedPresentationOnChange(Item)
	
	AccessManagementInternalClient.AccessKindsAllAllowedPresentationOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsAllAllowedPresentationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementInternalClient.AccessKindsAllAllowedPresentationChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
	
EndProcedure

#EndRegion

#Region AccessValueFormTableItemsEventHandlers

&AtClient
Procedure AccessValuesOnChange(Item)
	
	AccessManagementInternalClient.AccessValuesOnChange(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessValuesOnStartEdit(Item, NewRow, Clone)
	
	AccessManagementInternalClient.AccessValuesOnStartEdit(
		ThisObject, Item, NewRow, Clone);
	
EndProcedure

&AtClient
Procedure AccessValuesOnEndEdit(Item, NewRow, CancelEdit)
	
	AccessManagementInternalClient.AccessValuesOnEndEdit(
		ThisObject, Item, NewRow, CancelEdit);
	
EndProcedure

&AtClient
Procedure AccessValueStartChoice(Item, ChoiceData, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueStartChoice(
		ThisObject, Item, ChoiceData, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueChoiceProcessing(
		ThisObject, Item, ValueSelected, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueClearing(Item, StandardProcessing)
	
	AccessManagementInternalClient.AccessValueClearing(
		ThisObject, Item, StandardProcessing);
	
EndProcedure

&AtClient
Procedure AccessValueAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting)
	
	AccessManagementInternalClient.AccessValueAutoComplete(
		ThisObject, Item, Text, ChoiceData, DataGetParameters, Waiting);
	
EndProcedure

&AtClient
Procedure AccessValueTextInputCompletion(Item, Text, ChoiceData, DataGetParameters)
	
	AccessManagementInternalClient.AccessValueTextInputCompletion(
		ThisObject, Item, Text, ChoiceData, DataGetParameters);
	
EndProcedure

#EndRegion

#Region RolesFormTableItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure RolesCheckOnChange(Item)
	
	TableRow = Items.Roles.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	If TableRow.Check AND TableRow.Name = "InteractiveOpenExtReportsAndDataProcessors" Then
		Notification = New NotifyDescription("RolesMarkOnChangeAfterConfirm", ThisObject);
		FormParameters = New Structure("Key", "BeforeSelectRole");
		OpenForm("CommonForm.SecurityWarning", FormParameters, , , , , Notification);
	Else
		ProcessRolesInterface("UpdateRoleComposition");
	EndIf;
	
EndProcedure

&AtClient
Procedure RolesMarkOnChangeAfterConfirm(Response, ExecutionParameters) Export
	TableRow = Items.Roles.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	If Response = "Continue" Then
		ProcessRolesInterface("UpdateRoleComposition");
	Else
		TableRow.Check = False;
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure WriteAndClose(Command)
	
	Write(New Structure("WriteAndClose"));
	
EndProcedure

&AtClient
Procedure RestoreByInitialFilling(Command)
	
	ShowQueryBox(
		New NotifyDescription("RestoreByInitialFillingFollowUp", ThisObject),
		NStr("ru = 'Восстановить профиль по содержимому начального заполнения?'; en = 'Do you want to restore the profile based on the initial filling?'; pl = 'Czy chcesz przywrócić profil na podstawie początkowego wypełnienia?';es_ES = '¿Restablecer el perfil a su estado inicial?';es_CO = '¿Restablecer el perfil a su estado inicial?';tr = 'Profilin ilk durumu tekrar yüklensin mi?';it = 'Volete ripristinare il profilo in base alla compilazione iniziale?';de = 'Stellen Sie das Profil in den Ausgangszustand zurück?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure SnowUnusedAccessKinds(Command)
	
	ShowUnusedAccessKindsAtServer();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtClient
Procedure ShowSelectedRolesOnly(Command)
	
	ProcessRolesInterface("SelectedRolesOnly");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure RolesBySubsystemsGroup(Command)
	
	ProcessRolesInterface("GroupBySubsystems");
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
EndProcedure

&AtClient
Procedure AddRoles(Command)
	
	ProcessRolesInterface("UpdateRoleComposition", "EnableAll");
	
	UsersInternalClient.ExpandRoleSubsystems(ThisObject, False);
	
EndProcedure

&AtClient
Procedure RemoveRoles(Command)
	
	ProcessRolesInterface("UpdateRoleComposition", "DisableAll");
	
EndProcedure

&AtClient
Procedure SelectAssignment(Command)
	NotifyDescription = New NotifyDescription("AfterAssignmentChoice", ThisObject);
	UsersInternalClient.SelectPurpose(ThisObject, NStr("ru = 'Выбор назначения профиля групп доступа'; en = 'Select an assignment of access group profile'; pl = 'Wybór przydziału profilu grup dostępu';es_ES = 'Selección de asignación del perfil de grupos de acceso';es_CO = 'Selección de asignación del perfil de grupos de acceso';tr = 'Erişim grubu profilini seç';it = 'Selezionare assegnazione del profilo del gruppo di accesso';de = 'Auswahl für die Zuordnung des Zugriffsgruppenprofils'"),,, NotifyDescription);
EndProcedure

#EndRegion

#Region Private

// The BeforeWrite event handler continuation.
&AtClient
Procedure BeforeWriteFollowUpIdleHandler()
	
	WriteParameters = WriteParametersBeforeWriteFollowUp;
	WriteParametersBeforeWriteFollowUp = Undefined;
	
	If CheckFilling() Then
		ShowQueryBox(
			New NotifyDescription("BeforeWriteFollowUp", ThisObject, WriteParameters),
			QuestionTextUpdateProfileAccessGroups(),
			QuestionDialogMode.YesNoCancel,
			,
			DialogReturnCode.No);
	EndIf;
	
EndProcedure

// The BeforeWrite event handler continuation.
&AtClient
Procedure BeforeWriteFollowUp(Response, WriteParameters) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Response = DialogReturnCode.Yes Then
		WriteParameters.Insert("UpdateProfileAccessGroups");
	EndIf;
	
	WriteParameters.Insert("ProfileAccessGroupsUpdateResponseReceived");
	
	Write(WriteParameters);
	
EndProcedure

// The RestoreByInitialFilling command handler continued.
&AtClient
Procedure RestoreByInitialFillingFollowUp(Response, Context) Export
	
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ShowQueryBox(
		New NotifyDescription("RestoreByInitialFillingCompletion", ThisObject),
		QuestionTextUpdateProfileAccessGroups(),
		QuestionDialogMode.YesNoCancel,
		,
		DialogReturnCode.No);
	
EndProcedure

// The RestoreByInitialFilling command handler continued.
&AtClient
Procedure RestoreByInitialFillingCompletion(Response, Context) Export
	
	If Response = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	If Modified OR ObjectWasWritten Then
		UnlockFormDataForEdit();
	EndIf;
	
	UpdateAccessGroups = (Response = DialogReturnCode.Yes);
	
	ProfileAccessGroups = Undefined;
	InitialAccessGroupProfileFilling(UpdateAccessGroups, ProfileAccessGroups);
	
	Read();
	UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	
	If UpdateAccessGroups Then
		Text =
			NStr("ru = 'Профиль ""%1"" восстановлен по содержимому начального заполнения,
			           |группы доступа профиля обновлены.'; 
			           |en = 'Profile ""%1"" is restored to its initial state.
			           |Its access groups are updated.'; 
			           |pl = 'Profil ""%1"" został przywrócony do stanu początkowego,
			           |grupy dostępu do profilu są aktualizowane.';
			           |es_ES = 'El perfil ""%1"" se ha restablecido por el contenido del relleno inicial,
			           |los grupos de acceso del perfil se han actualizado.';
			           |es_CO = 'El perfil ""%1"" se ha restablecido por el contenido del relleno inicial,
			           |los grupos de acceso del perfil se han actualizado.';
			           |tr = '""%1"" profili ilk durumuna geri yüklendi.
			           |Erişim grupları güncellendi.';
			           |it = 'Profilo ""%1"" ripristinato allo stato iniziale.
			           |I suoi gruppi di accesso sono aggiornati.';
			           |de = 'Das Profil ""%1"" wurde basierend auf dem ursprünglichen Inhalt wiederhergestellt,
			           |die Profilzugriffsgruppen wurden aktualisiert.'");
	Else
		Text =
			NStr("ru = 'Профиль ""%1"" восстановлен по содержимому начального заполнения,
			           |группы доступа профиля не обновлены.'; 
			           |en = 'Profile ""%1"" is restored to its initial state.
			           |Its access groups are not updated.'; 
			           |pl = 'Profil ""%1"" został przywrócony do stanu początkowego,
			           |grupy dostępu do profilu nie są aktualizowane.';
			           |es_ES = 'El perfil ""%1"" se ha restablecido por el contenido del relleno inicial,
			           |los grupos de acceso del perfil no se han actualizado.';
			           |es_CO = 'El perfil ""%1"" se ha restablecido por el contenido del relleno inicial,
			           |los grupos de acceso del perfil no se han actualizado.';
			           |tr = '""%1"" profili ilk durumuna geri yüklendi.
			           |Erişim grupları güncellenmedi.';
			           |it = 'Profilo ""%1"" ripristinato allo stato iniziale.
			           |I suoi gruppi di accesso non sono aggiornati.';
			           |de = 'Das Profil ""%1"" wurde basierend auf dem ursprünglichen Inhalt wiederhergestellt,
			           |die Profilzugriffsgruppen wurden nicht aktualisiert.'");
	EndIf;
	
	ShowUserNotification(NStr("ru = 'Профиль восстановлен'; en = 'Profile restored'; pl = 'Profil został przywrócony';es_ES = 'Perfil restablecido';es_CO = 'Perfil restablecido';tr = 'Profil geri yüklendi';it = 'Profilo ripristinato';de = 'Profil wiederhergestellt'"),
		GetURL(Object.Ref),
		StringFunctionsClientServer.SubstituteParametersToString(Text, Object.Description));
	
	Notify("Write_AccessGroupProfiles", New Structure, Object.Ref);
	
	If UpdateAccessGroups Then
		NotifyChanged(Type("CatalogRef.AccessGroups"));
		
		For each ProfileAccessGroup In ProfileAccessGroups Do
			Notify("Write_AccessGroups", New Structure, ProfileAccessGroup);
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure ShowUnusedAccessKindsAtServer()
	
	AccessManagementInternal.RefreshUnusedAccessKindsRepresentation(ThisObject);
	
EndProcedure

&AtServer
Procedure SetAvailabilityToDescribeAndRestoreSuppliedProfile(CurrentObject = Undefined)
	
	If CurrentObject = Undefined Then
		CurrentObject = Object;
	EndIf;
	
	If Catalogs.AccessGroupProfiles.HasInitialProfileFilling(CurrentObject.Ref) Then
		
		SuppliedProfileDetails =
			Catalogs.AccessGroupProfiles.SuppliedProfileDetails(CurrentObject.Ref);
		
		If Catalogs.AccessGroupProfiles.SuppliedProfileChanged(CurrentObject) Then
			// Defining the rights to restore based on the initial filling.
			Items.RestoreByInitialFilling.Visible =
				Users.IsFullUser(,, False);
			
			Items.SuppliedProfileChanged.Visible = True;
		Else
			Items.RestoreByInitialFilling.Visible = False;
			Items.SuppliedProfileChanged.Visible = False;
		EndIf;
		
		Items.Comment2.Visible = False;
	Else
		Items.RestoreByInitialFilling.Visible = False;
		Items.SuppliedProfileDetails.Visible = False;
		Items.SuppliedProfileChanged.Visible = False;
		Items.Comment1.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Function QuestionTextUpdateProfileAccessGroups()
	
	Return
		NStr("ru = 'Обновить группы доступа, использующие этот профиль?
		           |
		           |Будут удалены лишние виды доступа с заданными для них
		           |значениями доступа и добавлены недостающие виды доступа.'; 
		           |en = 'Update access groups that use this profile?
		           |
		           |Excess access kinds with set
		           |access values will be deleted, and missing access kinds will be added.'; 
		           |pl = 'Czy chcesz zaktualizować grupy dostępu, które używają tego profilu? 
		           |
		           |Zbędne typy dostępu z określonymi wartościami
		           | dostępu zostaną usunięte, a brakujące rodzaje dostępu zostaną dodane.';
		           |es_ES = '¿Quiere actualizar los grupos de acceso utilizados por el perfil?
		           |
		           |Tipos de acceso en exceso con los valores de acceso especificados
		           |se borrarán, y los tipos de acceso que faltan, se añadirán.';
		           |es_CO = '¿Quiere actualizar los grupos de acceso utilizados por el perfil?
		           |
		           |Tipos de acceso en exceso con los valores de acceso especificados
		           |se borrarán, y los tipos de acceso que faltan, se añadirán.';
		           |tr = 'Bu profili kullanan erişim gruplarını güncellemek ister misiniz?
		           |
		           |Belirtilen
		           |erişim değerlerine sahip aşırı erişim türleri silinecek ve eksik erişim türleri eklenecektir.';
		           |it = 'Aggiornare i gruppi di accesso che utilizzano questo profilo?
		           |
		           |I tipi di accesso superflui con set di valori di accesso 
		           |saranno cancellati e saranno aggiunti i tipi di accesso mancante.';
		           |de = 'Zugriffsgruppen mit diesem Profil aktualisieren?
		           |
		           |Unnötige Zugriffsarten mit ihren angegebenen
		           |Zugriffswerten werden gelöscht und die fehlenden Zugriffsarten hinzugefügt.'");
		
EndFunction

&AtClient
Procedure CloseForm()
	
	Close();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Required by a role interface.

&AtServer
Procedure ProcessRolesInterface(Action, MainParameter = Undefined)
	
	ActionParameters = New Structure;
	ActionParameters.Insert("MainParameter", MainParameter);
	ActionParameters.Insert("Form",            ThisObject);
	ActionParameters.Insert("RolesCollection",   RolesCollection);
	
	ActionParameters.Insert("HideFullAccessRole",
		Object.Ref <> Catalogs.AccessGroupProfiles.Administrator);
	
	ActionParameters.Insert("RolesAssignment",
		AccessManagementInternalClientServer.ProfileAssignment(Object));
	
	UsersInternal.ProcessRolesInterface(Action, ActionParameters);
	
EndProcedure

&AtServer
Procedure InitialAccessGroupProfileFilling(Val UpdateAccessGroups, ProfileAccessGroups)
	
	Catalogs.AccessGroupProfiles.FillSuppliedProfile(
		Object.Ref, UpdateAccessGroups);
	
	If Not UpdateAccessGroups Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Profile", Object.Ref);
	Query.Text =
	"SELECT
	|	AccessGroups.Ref AS Ref
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|WHERE
	|	AccessGroups.Profile = &Profile";
	
	ProfileAccessGroups = Query.Execute().Unload().UnloadColumn("Ref");
	
EndProcedure

&AtClient
Procedure AfterAssignmentChoice(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		Modified = True;
		ProcessRolesInterface("RefreshRoleTree");
		UsersInternalClient.ExpandRoleSubsystems(ThisObject);
	EndIf;
	
EndProcedure

#EndRegion
