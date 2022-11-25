
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If NOT ValueIsFilled(Parameters.User) Then
		Cancel = True;
		Return;
	EndIf;
	
	CurrentRestrictionsAvailability = True;
	EditCurrentRestrictions = True;
	
	If Users.IsFullUser() Then
		// Viewing and editing profile content and access restrictions.
		FilterProfilesOnlyForCurrentUser = False;
		
	ElsIf Parameters.User = Users.AuthorizedUser() Then
		// Viewing your profiles and the access rights report.
		FilterProfilesOnlyForCurrentUser = True;
		// Hiding unused information.
		Items.Profiles.ReadOnly = True;
		Items.ProfilesCheck.Visible = False;
		Items.Access.Visible = False;
		Items.FormWrite.Visible = False;
	Else
		Items.FormWrite.Visible = False;
		Items.FormAccessRightsReport.Visible = False;
		Items.RightsAndRestrictions.Visible = False;
		Items.InsufficientViewRights.Visible = True;
		Return;
	EndIf;
	
	If TypeOf(Parameters.User) = Type("CatalogRef.ExternalUsers") Then
		Items.Profiles.Title = NStr("ru = 'Профили внешнего пользователя'; en = 'External user profiles'; pl = 'Zewnętrzne profile użytkowników';es_ES = 'Perfiles de usuario externo';es_CO = 'Perfiles de usuario externo';tr = 'Harici kullanıcı profilleri';it = 'profili utente esterno';de = 'Externe Benutzerprofile'");
	Else
		Items.Profiles.Title = NStr("ru = 'Профили пользователя'; en = 'User profiles'; pl = 'Profile użytkowników';es_ES = 'Perfiles de usuario';es_CO = 'Perfiles de usuario';tr = 'Kullanıcı profilleri';it = 'Profili utente';de = 'Benutzerprofil'");
	EndIf;
	
	ImportData(FilterProfilesOnlyForCurrentUser);
	
	// Preparing auxiliary data.
	AccessManagementInternal.OnCreateAtServerAllowedValuesEditForm(ThisObject, , "");
	
	For each ProfileProperties In Profiles Do
		CurrentAccessGroup = ProfileProperties.Profile;
		AccessManagementInternalClientServer.FillAccessKindsPropertiesInForm(ThisObject);
	EndDo;
	CurrentAccessGroup = "";
	
	ProfileAdministrator = Catalogs.AccessGroupProfiles.Administrator;
	
	// Determining if the access restrictions must be set.
	If NOT AccessManagement.LimitAccessAtRecordLevel() Then
		Items.Access.Visible = False;
	EndIf;
	
	If Common.DataSeparationEnabled()
	   AND Common.SubsystemExists("StandardSubsystems.SaaS.UsersSaaS") Then
		
		ModuleUsersInternalSaaS = Common.CommonModule("UsersInternalSaaS");
		ActionsWithSaaSUser = ModuleUsersInternalSaaS.GetActionsWithSaaSUser();
		
		AdministrativeAccessChangeProhibition = NOT ActionsWithSaaSUser.ChangeAdministrativeAccess;
	EndIf;
	
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject, "Access");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If TypeOf(FormOwner) <> Type("ClientApplicationForm")
	 Or FormOwner.Window <> Window Then
		
		AutoTitle = False;
		Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Права доступа (%1)'; en = 'Access rights (%1)'; pl = 'Prawa dostępu (%1)';es_ES = 'Derecho de acceso (%1)';es_CO = 'Derecho de acceso (%1)';tr = 'Erişim hakları (%1)';it = 'Permessi di accesso (%1)';de = 'Zugriffsrechte (%1)'"), String(Parameters.User));
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	Notification = New NotifyDescription("WriteAndCloseNotification", ThisObject);
	CommonClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// Checking for blank and duplicate access values.
	Errors = Undefined;
	
	For each ProfileProperties In Profiles Do
		
		CurrentAccessGroup = ProfileProperties.Profile;
		AccessManagementInternalClientServer.ProcessingOfCheckOfFillingAtServerAllowedValuesEditForm(
			ThisObject, Cancel, New Array, Errors);
		
		If Cancel Then
			Break;
		EndIf;
		
	EndDo;
	
	If Cancel Then
		CurrentAccessKindRow = Items.AccessKinds.CurrentRow;
		CurrentAccessValueRowOnError = Items.AccessValues.CurrentRow;
		
		Items.Profiles.CurrentRow = ProfileProperties.GetID();
		OnChangeCurrentProfile(ThisObject, False);
		
		Items.AccessKinds.CurrentRow = CurrentAccessKindRow;
		AccessManagementInternalClientServer.OnChangeCurrentAccessKind(ThisObject, False);
		
		CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	Else
		CurrentAccessGroup = CurrentProfile;
	EndIf;
	
EndProcedure

&AtClient
Procedure SetCurrentAccessValueRowOnError()
	
	If CurrentAccessValueRowOnError <> Undefined Then
		Items.AccessValues.CurrentRow = CurrentAccessValueRowOnError;
		CurrentAccessValueRowOnError = Undefined;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersProfiles

&AtClient
Procedure ProfilesOnActivateRow(Item)
	
	OnChangeCurrentProfile(ThisObject);
	
EndProcedure

&AtClient
Procedure ProfilesCheckOnChange(Item)
	
	Cancel = False;
	CurrentData = Items.Profiles.CurrentData;
	
	If CurrentData <> Undefined
	   AND NOT CurrentData.Check Then
		// Checking blank and duplicate access values before disabling the profile and access to its 
		// settings.
		ClearMessages();
		Errors = Undefined;
		AccessManagementInternalClientServer.ProcessingOfCheckOfFillingAtServerAllowedValuesEditForm(
			ThisObject, Cancel, New Array, Errors);
		CurrentAccessValueRowOnError = Items.AccessValues.CurrentRow;
		CommonClientServer.ReportErrorsToUser(Errors, Cancel);
		AttachIdleHandler("SetCurrentAccessValueRowOnError", True, 0.1);
	EndIf;
	
	If Cancel Then
		CurrentData.Check = True;
	Else
		OnChangeCurrentProfile(ThisObject);
	EndIf;
	
	If CurrentData <> Undefined
		AND CurrentData.Profile = PredefinedValue("Catalog.AccessGroupProfiles.Administrator") Then
		
		SynchronizationWithServiceRequired = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region AccessKindsFormTableItemsEventHandlers

&AtClient
Procedure AccessKindsChoice(Item, RowSelected, Field, StandardProcessing)
	
	If EditCurrentRestrictions Then
		Items.AccessKinds.ChangeRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateRow(Item)
	
	AccessManagementInternalClient.AccessKindsOnActivateRow(
		ThisObject, Item);
	
EndProcedure

&AtClient
Procedure AccessKindsOnActivateCell(Item)
	
	AccessManagementInternalClient.AccessKindsOnActivateCell(
		ThisObject, Item);
	
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

#Region FormCommandHandlers

&AtClient
Procedure Write(Command)
	
	WriteChanges();
	
EndProcedure

&AtClient
Procedure AccessRightsReport(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("User", Parameters.User);
	
	OpenForm("Report.AccessRights.Form", FormParameters);
	
EndProcedure

&AtClient
Procedure SnowUnusedAccessKinds(Command)
	
	ShowUnusedAccessKindsAtServer();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesCheck.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Profiles.Profile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Catalogs.AccessGroupProfiles.Administrator;

	Item.Appearance.SetParameterValue("Enabled", False);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesCheck.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ProfilesProfilePresentation.Name);

	FIlterGroup1 = Item.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
	FIlterGroup1.GroupType = DataCompositionFilterItemsGroupType.AndGroup;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("AdministrativeAccessChangeProhibition");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;

	ItemFilter = FIlterGroup1.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Profiles.Profile");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Catalogs.AccessGroupProfiles.Administrator;

	Item.Appearance.SetParameterValue("BackColor", StyleColors.InaccessibleCellTextColor);

EndProcedure

// The BeforeClose event handler continuation.
&AtClient
Procedure WriteAndCloseNotification(Result, Context) Export
	
	WriteChanges(New NotifyDescription("WriteAndCloseCompletion", ThisObject));
	
EndProcedure

// The BeforeClose event handler continuation.
&AtClient
Procedure WriteAndCloseCompletion(Cancel, Context) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure WriteChanges(ContinuationHandler = Undefined)
	
	If StandardSubsystemsClient.ClientRunParameters().DataSeparationEnabled
	   AND SynchronizationWithServiceRequired Then
		
		UsersInternalClient.RequestPasswordForAuthenticationInService(
			New NotifyDescription("SaveChangesCompletion", ThisObject, ContinuationHandler),
			ThisObject,
			ServiceUserPassword);
	Else
		SaveChangesCompletion(Null, ContinuationHandler);
	EndIf;
	
EndProcedure

&AtClient
Procedure SaveChangesCompletion(SaaSUserNewPassword, ContinuationHandler) Export
	
	If SaaSUserNewPassword = Undefined Then
		Return;
	EndIf;
	
	If SaaSUserNewPassword <> Null Then
		ServiceUserPassword = SaaSUserNewPassword;
	EndIf;
	
	ClearMessages();
	
	Cancel = False;
	CancelOnWriteChanges = False;
	Try
		WriteChangesAtServer(Cancel);
	Except
		ErrorInformation = ErrorInfo();
		If CancelOnWriteChanges Then
			CommonClientServer.MessageToUser(
				BriefErrorDescription(ErrorInformation),,,, Cancel);
		Else
			Raise;
		EndIf;
	EndTry;
	
	AttachIdleHandler("SetCurrentAccessValueRowOnError", True, 0.1);
	
	If ContinuationHandler = Undefined Then
		Return;
	EndIf;
	
	ExecuteNotifyProcessing(ContinuationHandler, Cancel);
	
EndProcedure

&AtServer
Procedure ShowUnusedAccessKindsAtServer()
	
	AccessManagementInternal.RefreshUnusedAccessKindsRepresentation(ThisObject);
	
EndProcedure

&AtServer
Procedure ImportData(FilterProfilesOnlyForCurrentUser)
	
	Query = New Query;
	Query.SetParameter("User", Parameters.User);
	Query.SetParameter("FilterProfilesOnlyForCurrentUser",
	                           FilterProfilesOnlyForCurrentUser);
	Query.SetParameter("ProfileIDDocumentsPricesEdit", New UUID("76337579-bff4-11df-9174-e0cb4ed5f4c3"));
	Query.SetParameter("ProfileIDProductsEdit" , New UUID("76337580-bff4-11df-9174-e0cb4ed5f4c3"));
	Query.SetParameter("ProfileIDReturnsFromCustomers" 	   , New UUID("76337581-bff4-11df-9174-e0cb4ed5f4c3"));
	Query.SetParameter("ProfileIDReturnsToSuppliers" 	   , New UUID("76337582-bff4-11df-9174-e0cb4ed5f4c3"));
	Query.SetParameter("ProfileIDDataSynchronization" 	   , New UUID("04937803-5dba-11df-a1d4-005056c00008"));
	Query.Text =
	"SELECT DISTINCT
	|	Profiles.Ref AS Ref,
	|	ISNULL(AccessGroups.Ref, UNDEFINED) AS PersonalAccessGroup,
	|	CASE
	|		WHEN AccessGroupsUsers.Ref IS NULL
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Check
	|INTO Profiles
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroups AS AccessGroups
	|		ON Profiles.Ref = AccessGroups.Profile
	|			AND (NOT(AccessGroups.User <> &User
	|					AND NOT Profiles.Ref IN (VALUE(Catalog.AccessGroupProfiles.Administrator))))
	|		LEFT JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (AccessGroups.Ref = AccessGroupsUsers.Ref)
	|			AND (AccessGroupsUsers.User = &User)
	|WHERE
	|	NOT Profiles.DeletionMark
	|	AND NOT(&FilterProfilesOnlyForCurrentUser = TRUE
	|				AND AccessGroupsUsers.Ref IS NULL)
	|	AND NOT Profiles.SuppliedDataID = &ProfileIDDocumentsPricesEdit
	|	AND NOT Profiles.SuppliedDataID = &ProfileIDProductsEdit
	|	AND NOT Profiles.SuppliedDataID = &ProfileIDReturnsFromCustomers
	|	AND NOT Profiles.SuppliedDataID = &ProfileIDReturnsToSuppliers
	|	AND NOT Profiles.SuppliedDataID = &ProfileIDDataSynchronization
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	Profiles.Ref.Description AS ProfilePresentation,
	|	Profiles.Check AS Check,
	|	Profiles.PersonalAccessGroup AS AccessGroup
	|FROM
	|	Profiles AS Profiles
	|
	|ORDER BY
	|	ProfilePresentation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS AccessGroup,
	|	ProfilesAccessKinds.AccessKind AS AccessKind,
	|	ISNULL(AccessGroupsAccessKinds.AllAllowed, ProfilesAccessKinds.AllAllowed) AS AllAllowed,
	|	"""" AS AccessTypePresentation,
	|	"""" AS AllAllowedPresentation
	|FROM
	|	Profiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds
	|		ON Profiles.Ref = ProfilesAccessKinds.Ref
	|		LEFT JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessKinds.Ref
	|			AND (ProfilesAccessKinds.AccessKind = AccessGroupsAccessKinds.AccessKind)
	|WHERE
	|	NOT ProfilesAccessKinds.PresetAccessKind
	|
	|ORDER BY
	|	Profiles.Ref.Description,
	|	ProfilesAccessKinds.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS AccessGroup,
	|	ProfilesAccessKinds.AccessKind AS AccessKind,
	|	0 AS RowNumberByKind,
	|	AccessGroupsAccessValues.AccessValue AS AccessValue
	|FROM
	|	Profiles AS Profiles
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfilesAccessKinds
	|		ON Profiles.Ref = ProfilesAccessKinds.Ref
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessValues.Ref
	|			AND (ProfilesAccessKinds.AccessKind = AccessGroupsAccessValues.AccessKind)
	|WHERE
	|	NOT ProfilesAccessKinds.PresetAccessKind
	|
	|ORDER BY
	|	Profiles.Ref.Description,
	|	ProfilesAccessKinds.LineNumber,
	|	AccessGroupsAccessValues.LineNumber";
	
	SetPrivilegedMode(True);
	QueryResults = Query.ExecuteBatch();
	SetPrivilegedMode(False);
	
	ValueToFormAttribute(QueryResults[1].Unload(), "Profiles");
	ValueToFormAttribute(QueryResults[2].Unload(), "AccessKinds");
	ValueToFormAttribute(QueryResults[3].Unload(), "AccessValues");
	
EndProcedure

&AtServer
Procedure WriteChangesAtServer(Cancel)
	
	If Not CheckFilling() Then
		Cancel = True;
		Return;
	EndIf;
	
	Users.FindAmbiguousIBUsers(Undefined);
	
	// Getting a change list.
	Query = New Query;
	
	Query.SetParameter("User", Parameters.User);
	
	Query.SetParameter(
		"Profiles", Profiles.Unload(, "Profile, Check"));
	
	Query.SetParameter(
		"AccessKinds", AccessKinds.Unload(, "AccessGroup, AccessKind, AllAllowed"));
	
	ValueTable = AccessValues.Unload(, "AccessGroup, AccessKind, AccessValue");
	ValueTable.Columns.Add("LineNumber", New TypeDescription("Number",,,
		New NumberQualifiers(10, 0, AllowedSign.Nonnegative)));
	
	AccessGroupInRow = Undefined;
	For Each Row In ValueTable Do
		If AccessGroupInRow <> Row.AccessGroup Then
			AccessGroupInRow = Row.AccessGroup;
			CurrentRowNumber = 1;
		EndIf;
		Row.LineNumber = CurrentRowNumber;
		CurrentRowNumber = CurrentRowNumber + 1;
	EndDo;
	Query.SetParameter("AccessValues", ValueTable);
	
	Query.Text =
	"SELECT
	|	Profiles.Profile AS Ref,
	|	Profiles.Check
	|INTO Profiles
	|FROM
	|	&Profiles AS Profiles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKinds.AccessGroup AS Profile,
	|	AccessKinds.AccessKind,
	|	AccessKinds.AllAllowed
	|INTO AccessKinds
	|FROM
	|	&AccessKinds AS AccessKinds
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessValues.AccessGroup AS Profile,
	|	AccessValues.AccessKind,
	|	AccessValues.LineNumber,
	|	AccessValues.AccessValue
	|INTO AccessValues
	|FROM
	|	&AccessValues AS AccessValues
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Profiles.Ref,
	|	ISNULL(AccessGroups.Ref, UNDEFINED) AS PersonalAccessGroup,
	|	CASE
	|		WHEN AccessGroupsUsers.Ref IS NULL 
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS Check
	|INTO CurrentProfiles
	|FROM
	|	Catalog.AccessGroupProfiles AS Profiles
	|		LEFT JOIN Catalog.AccessGroups AS AccessGroups
	|		ON Profiles.Ref = AccessGroups.Profile
	|			AND (NOT(AccessGroups.User <> &User
	|					AND NOT Profiles.Ref IN (VALUE(Catalog.AccessGroupProfiles.Administrator))))
	|		LEFT JOIN Catalog.AccessGroups.Users AS AccessGroupsUsers
	|		ON (AccessGroups.Ref = AccessGroupsUsers.Ref)
	|			AND (AccessGroupsUsers.User = &User)
	|WHERE
	|	NOT Profiles.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	AccessGroupsAccessKinds.AccessKind,
	|	AccessGroupsAccessKinds.AllAllowed
	|INTO CurrentAccessKinds
	|FROM
	|	CurrentProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessGroupsAccessKinds
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessKinds.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	AccessGroupsAccessValues.AccessKind,
	|	AccessGroupsAccessValues.LineNumber,
	|	AccessGroupsAccessValues.AccessValue
	|INTO CurrentAccessValues
	|FROM
	|	CurrentProfiles AS Profiles
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|		ON Profiles.PersonalAccessGroup = AccessGroupsAccessValues.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ChangedGroupsProfiles.Profile
	|INTO ChangedGroupsProfiles
	|FROM
	|	(SELECT
	|		Profiles.Ref AS Profile
	|	FROM
	|		Profiles AS Profiles
	|			INNER JOIN CurrentProfiles AS CurrentProfiles
	|			ON Profiles.Ref = CurrentProfiles.Ref
	|	WHERE
	|		Profiles.Check <> CurrentProfiles.Check
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessKinds.Profile
	|	FROM
	|		AccessKinds AS AccessKinds
	|			LEFT JOIN CurrentAccessKinds AS CurrentAccessKinds
	|			ON AccessKinds.Profile = CurrentAccessKinds.Profile
	|				AND AccessKinds.AccessKind = CurrentAccessKinds.AccessKind
	|				AND AccessKinds.AllAllowed = CurrentAccessKinds.AllAllowed
	|	WHERE
	|		CurrentAccessKinds.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CurrentAccessKinds.Profile
	|	FROM
	|		CurrentAccessKinds AS CurrentAccessKinds
	|			LEFT JOIN AccessKinds AS AccessKinds
	|			ON (AccessKinds.Profile = CurrentAccessKinds.Profile)
	|				AND (AccessKinds.AccessKind = CurrentAccessKinds.AccessKind)
	|				AND (AccessKinds.AllAllowed = CurrentAccessKinds.AllAllowed)
	|	WHERE
	|		AccessKinds.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		AccessValues.Profile
	|	FROM
	|		AccessValues AS AccessValues
	|			LEFT JOIN CurrentAccessValues AS CurrentAccessValues
	|			ON AccessValues.Profile = CurrentAccessValues.Profile
	|				AND AccessValues.AccessKind = CurrentAccessValues.AccessKind
	|				AND AccessValues.LineNumber = CurrentAccessValues.LineNumber
	|				AND AccessValues.AccessValue = CurrentAccessValues.AccessValue
	|	WHERE
	|		CurrentAccessValues.AccessKind IS NULL 
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CurrentAccessValues.Profile
	|	FROM
	|		CurrentAccessValues AS CurrentAccessValues
	|			LEFT JOIN AccessValues AS AccessValues
	|			ON (AccessValues.Profile = CurrentAccessValues.Profile)
	|				AND (AccessValues.AccessKind = CurrentAccessValues.AccessKind)
	|				AND (AccessValues.LineNumber = CurrentAccessValues.LineNumber)
	|				AND (AccessValues.AccessValue = CurrentAccessValues.AccessValue)
	|	WHERE
	|		AccessValues.AccessKind IS NULL ) AS ChangedGroupsProfiles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Profiles.Ref AS Profile,
	|	CatalogProfiles.Description AS ProfileDescription,
	|	Profiles.Check,
	|	CurrentProfiles.PersonalAccessGroup
	|FROM
	|	ChangedGroupsProfiles AS ChangedGroupsProfiles
	|		INNER JOIN Profiles AS Profiles
	|		ON ChangedGroupsProfiles.Profile = Profiles.Ref
	|		INNER JOIN CurrentProfiles AS CurrentProfiles
	|		ON ChangedGroupsProfiles.Profile = CurrentProfiles.Ref
	|		INNER JOIN Catalog.AccessGroupProfiles AS CatalogProfiles
	|		ON (CatalogProfiles.Ref = ChangedGroupsProfiles.Profile)";
	
	BeginTransaction();
	Try
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			If ValueIsFilled(Selection.PersonalAccessGroup) Then
				LockDataForEdit(Selection.PersonalAccessGroup);
				AccessGroupObject = Selection.PersonalAccessGroup.GetObject();
				AccessGroupObject.DeletionMark = False;
			Else
				// Creating a personal access group.
				AccessGroupObject = Catalogs.AccessGroups.CreateItem();
				AccessGroupObject.Parent     = Catalogs.AccessGroups.PersonalAccessGroupsParent();
				AccessGroupObject.Description = Selection.ProfileDescription;
				AccessGroupObject.User = Parameters.User;
				AccessGroupObject.Profile      = Selection.Profile;
			EndIf;
			
			If Selection.Profile = Catalogs.AccessGroupProfiles.Administrator Then
				
				If SynchronizationWithServiceRequired Then
					AccessGroupObject.AdditionalProperties.Insert("ServiceUserPassword", ServiceUserPassword);
				EndIf;
				
				If Selection.Check Then
					If AccessGroupObject.Users.Find(
							Parameters.User, "User") = Undefined Then
						
						AccessGroupObject.Users.Add().User = Parameters.User;
					EndIf;
				Else
					UserDetails =  AccessGroupObject.Users.Find(
						Parameters.User, "User");
					
					If UserDetails <> Undefined Then
						AccessGroupObject.Users.Delete(UserDetails);
						
						If NOT Common.DataSeparationEnabled() Then
							// Checking a blank list of infobase users in the Administrators access group.
							ErrorDescription = "";
							AccessManagementInternal.CheckAdministratorsAccessGroupForIBUser(
								AccessGroupObject.Users, ErrorDescription);
							
							If ValueIsFilled(ErrorDescription) Then
								CancelOnWriteChanges = True;
								Cancel = True;
								Raise
									NStr("ru = 'Профиль Администратор должен быть хотя бы у одного пользователя,
									           |которому разрешен вход в программу.'; 
									           |en = 'At least one user that can sign in to the application
									           |must have the Administrator profile.'; 
									           |pl = 'Profil Administrator musi być przypisany chociażby do jednego użytkownika,
									           |posiadającego uprawnienia do wejścia do programu.';
									           |es_ES = 'Aunque sea un usuario debe tener el perfil Administrador,
									           |al que está permitido entrar en el programa.';
									           |es_CO = 'Aunque sea un usuario debe tener el perfil Administrador,
									           |al que está permitido entrar en el programa.';
									           |tr = 'Programa girmesine izin verilen en az bir kullanıcı, 
									           | Yönetici profiline sahip olmalıdır.';
									           |it = 'Almeno un utente che può accere all''applicazione
									           |deve avere un profilo da Amministratore.';
									           |de = 'Das Administrator-Profil muss von mindestens einem Benutzer gehalten werden,
									           |der sich am Programm anmelden darf.'");
							EndIf;
						EndIf;
					EndIf;
				EndIf;
			Else
				AccessGroupObject.Users.Clear();
				If Selection.Check Then
					AccessGroupObject.Users.Add().User = Parameters.User;
				EndIf;
				
				Filter = New Structure("AccessGroup", Selection.Profile);
				
				AccessGroupObject.AccessKinds.Load(
					AccessKinds.Unload(Filter, "AccessKind, AllAllowed"));
				
				AccessGroupObject.AccessValues.Load(
					AccessValues.Unload(Filter, "AccessKind, AccessValue"));
			EndIf;
			
			Try
				AccessGroupObject.Write();
			Except
				ServiceUserPassword = Undefined;
				Raise;
			EndTry;
			
			If ValueIsFilled(Selection.PersonalAccessGroup) Then
				UnlockDataForEdit(Selection.PersonalAccessGroup);
			EndIf;
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Modified = False;
	SynchronizationWithServiceRequired = False;
	
	AccessManagementInternal.AfterChangeRightsSettingsInForm();
	
EndProcedure

&AtClientAtServerNoContext
Procedure OnChangeCurrentProfile(Val Form, Val ProcessingAtClient = True)
	
	Items    = Form.Items;
	Profiles     = Form.Profiles;
	AccessKinds = Form.AccessKinds;
	
	If ProcessingAtClient Then
		CurrentData = Items.Profiles.CurrentData;
	Else
		CurrentData = Profiles.FindByID(
			?(Items.Profiles.CurrentRow = Undefined, -1, Items.Profiles.CurrentRow));
	EndIf;
	
	CurrentRestrictionsAvailabilityPrevious    = Form.CurrentRestrictionsAvailability;
	EditCurrentRestrictionsPrevious = Form.EditCurrentRestrictions;
	
	If CurrentData = Undefined Then
		Form.CurrentProfile = Undefined;
		Form.CurrentRestrictionsAvailability = False;
		Form.EditCurrentRestrictions = False;
	Else
		Form.CurrentProfile = CurrentData.Profile;
		Form.CurrentRestrictionsAvailability    = CurrentData.Check;
		Form.EditCurrentRestrictions = CurrentData.Check
			AND Form.CurrentProfile <> Form.ProfileAdministrator
			AND Not Form.ReadOnly;
	EndIf;
	
	CurrentRestrictionsDisplayUpdateRequired =
		    CurrentRestrictionsAvailabilityPrevious    <> Form.CurrentRestrictionsAvailability
		Or EditCurrentRestrictionsPrevious <> Form.EditCurrentRestrictions;
	
	If Form.CurrentProfile = Undefined Then
		Form.CurrentAccessGroup = "";
	Else
		Form.CurrentAccessGroup = Form.CurrentProfile;
	EndIf;
	
	If Items.AccessKinds.RowFilter = Undefined
	 OR Items.AccessKinds.RowFilter.AccessGroup <> Form.CurrentAccessGroup Then
		
		If Items.AccessKinds.RowFilter = Undefined Then
			RowsFilter = New Structure;
		Else
			RowsFilter = New Structure(Items.AccessKinds.RowFilter);
		EndIf;
		RowsFilter.Insert("AccessGroup", Form.CurrentAccessGroup);
		Items.AccessKinds.RowFilter = New FixedStructure(RowsFilter);
		CurrentAccessKinds = AccessKinds.FindRows(New Structure("AccessGroup", Form.CurrentAccessGroup));
		If CurrentAccessKinds.Count() = 0 Then
			Items.AccessValues.RowFilter = New FixedStructure("AccessGroup, AccessKind", Form.CurrentAccessGroup, "");
			AccessManagementInternalClientServer.OnChangeCurrentAccessKind(Form, ProcessingAtClient);
		Else
			Items.AccessKinds.CurrentRow = CurrentAccessKinds[0].GetID();
		EndIf;
	EndIf;
	
	If CurrentRestrictionsDisplayUpdateRequired Then
		If ProcessingAtClient Then
			Form.AttachIdleHandler("UpdateCurrentRestrictionsDisplayIdleHandler", 0.1, True);
		Else
			UpdateCurrentRestrictionsDisplay(Form);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateCurrentRestrictionsDisplayIdleHandler()
	
	UpdateCurrentRestrictionsDisplay(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateCurrentRestrictionsDisplay(Form)
	
	Items = Form.Items;
	
	Items.Access.Enabled                             =    Form.CurrentRestrictionsAvailability;
	Items.AccessKinds.ReadOnly                     = NOT Form.EditCurrentRestrictions;
	Items.AccessValuesByAccessKind.Enabled       =    Form.CurrentRestrictionsAvailability;
	Items.AccessValues.ReadOnly                 = NOT Form.EditCurrentRestrictions;
	Items.AccessKindsContextMenuChange.Enabled =    Form.EditCurrentRestrictions;
	
EndProcedure

#EndRegion
