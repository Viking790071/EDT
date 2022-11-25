#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// The procedure updates register data when changing
// - allowed access group values,
// - allowed access group profile values,
// - access kind usage.
// 
// Parameters:
//  AccessGroups - CatalogRef.AccessGroups.
//                - Array of values of the types specified above.
//                - Undefined - without filter.
//
//  HasChanges - Boolean (return value) - if recorded, True is set, otherwise, it is not changed.
//                  
//
Procedure UpdateRegisterData(AccessGroups = Undefined, HasChanges = Undefined) Export
	
	Lock = New DataLock;
	LockItem = Lock.Add("InformationRegister.AccessGroupsValues");
	LockItem = Lock.Add("InformationRegister.DefaultAccessGroupsValues");
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		UsedAccessKinds = New ValueTable;
		UsedAccessKinds.Columns.Add("AccessKind", Metadata.DefinedTypes.AccessValue.Type);
		UsedAccessKinds.Columns.Add("AccessKindUsers",        New TypeDescription("Boolean"));
		UsedAccessKinds.Columns.Add("AccessKindExternalUsers", New TypeDescription("Boolean"));
		AccessKindsProperties = AccessManagementInternal.AccessKindProperties();
		
		For each AccessKindProperties In AccessKindsProperties Do
			If Not AccessManagementInternal.AccessKindUsed(AccessKindProperties.Ref)
			   AND Not AccessKindProperties.Name = "AdditionalReportsAndDataProcessors" Then
				Continue;
			EndIf;
			NewRow = UsedAccessKinds.Add();
			NewRow.AccessKind = AccessKindProperties.Ref;
			NewRow.AccessKindUsers        = (AccessKindProperties.Name = "Users");
			NewRow.AccessKindExternalUsers = (AccessKindProperties.Name = "ExternalUsers");
		EndDo;
		
		UpdateAllowedValues(UsedAccessKinds, AccessGroups, HasChanges);
		
		UpdateDefaultAllowedValues(UsedAccessKinds, AccessGroups, HasChanges);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

Procedure UpdateAllowedValues(UsedAccessKinds, AccessGroups = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("UsedAccessKinds", UsedAccessKinds);
	
	Query.SetParameter("AccessKindsGroupsAndValuesTypes",
		AccessManagementInternalCached.AccessKindsGroupsAndValuesTypes());
	
	TemporaryTablesQueriesText =
	"SELECT
	|	UsedAccessKinds.AccessKind AS AccessKind,
	|	UsedAccessKinds.AccessKindUsers AS AccessKindUsers,
	|	UsedAccessKinds.AccessKindExternalUsers AS AccessKindExternalUsers
	|INTO UsedAccessKinds
	|FROM
	|	&UsedAccessKinds AS UsedAccessKinds
	|
	|INDEX BY
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Purpose.Ref AS Profile,
	|	MIN(VALUETYPE(Purpose.UsersType) = TYPE(Catalog.Users)) AS OnlyForUsers,
	|	MIN(VALUETYPE(Purpose.UsersType) <> TYPE(Catalog.Users)
	|			AND Purpose.UsersType <> UNDEFINED) AS ForExternalUsersOnly
	|INTO ProfilesPurpose
	|FROM
	|	Catalog.AccessGroupProfiles.Purpose AS Purpose
	|
	|GROUP BY
	|	Purpose.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesPurpose.Profile AS Profile,
	|	UsedAccessKinds.AccessKind AS AccessKind
	|INTO ProfileAccessKindsAllDenied
	|FROM
	|	UsedAccessKinds AS UsedAccessKinds
	|		INNER JOIN ProfilesPurpose AS ProfilesPurpose
	|		ON (UsedAccessKinds.AccessKindUsers
	|					AND NOT ProfilesPurpose.OnlyForUsers
	|				OR UsedAccessKinds.AccessKindExternalUsers
	|					AND NOT ProfilesPurpose.ForExternalUsersOnly)
	|
	|INDEX BY
	|	ProfilesPurpose.Profile,
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsGroupsAndValuesTypes.AccessKind AS AccessKind,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType AS GroupAndValueType
	|INTO AccessKindsGroupsAndValuesTypes
	|FROM
	|	&AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|
	|INDEX BY
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType,
	|	AccessKindsGroupsAndValuesTypes.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Profile AS Profile
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|		ON AccessGroups.Profile = AccessGroupProfiles.Ref
	|			AND (AccessGroups.Profile <> VALUE(Catalog.AccessGroupProfiles.Administrator))
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroupProfiles.DeletionMark)
	|			AND (&AccessGroupFilterCriterion1)
	|			AND (TRUE IN
	|				(SELECT TOP 1
	|					TRUE AS TrueValue
	|				FROM
	|					Catalog.AccessGroups.Users AS AccessGroupsMembers
	|				WHERE
	|					AccessGroupsMembers.Ref = AccessGroups.Ref))
	|
	|INDEX BY
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Profile AS Profile,
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileAccessValues.AccessKind AS AccessKind,
	|	ProfileAccessValues.AccessValue AS AccessValue,
	|	CASE
	|		WHEN ProfileAccessKinds.AllAllowed
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS ValueAllowed
	|INTO ValuesSettings
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfileAccessKinds
	|		ON AccessGroups.Profile = ProfileAccessKinds.Ref
	|			AND (ProfileAccessKinds.PresetAccessKind)
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessValues AS ProfileAccessValues
	|		ON (ProfileAccessValues.Ref = ProfileAccessKinds.Ref)
	|			AND (ProfileAccessValues.AccessKind = ProfileAccessKinds.AccessKind)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessGroups.Profile,
	|	AccessGroups.Ref,
	|	AccessValues.AccessKind,
	|	AccessValues.AccessValue,
	|	CASE
	|		WHEN AccessKinds.AllAllowed
	|			THEN FALSE
	|		ELSE TRUE
	|	END
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessKinds
	|		ON (AccessKinds.Ref = AccessGroups.Ref)
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS SpecifiedAccessKinds
	|		ON (SpecifiedAccessKinds.Ref = AccessGroups.Profile)
	|			AND (SpecifiedAccessKinds.AccessKind = AccessKinds.AccessKind)
	|			AND (NOT SpecifiedAccessKinds.PresetAccessKind)
	|		INNER JOIN Catalog.AccessGroups.AccessValues AS AccessValues
	|		ON (AccessValues.Ref = AccessGroups.Ref)
	|			AND (AccessValues.AccessKind = AccessKinds.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ValuesSettings.AccessGroup AS AccessGroup,
	|	ValuesSettings.AccessValue AS AccessValue,
	|	MAX(ValuesSettings.ValueAllowed) AS ValueAllowed
	|INTO NewData
	|FROM
	|	ValuesSettings AS ValuesSettings
	|		INNER JOIN AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|		ON ValuesSettings.AccessKind = AccessKindsGroupsAndValuesTypes.AccessKind
	|			AND (VALUETYPE(ValuesSettings.AccessValue) = VALUETYPE(AccessKindsGroupsAndValuesTypes.GroupAndValueType))
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON ValuesSettings.AccessKind = UsedAccessKinds.AccessKind
	|			AND (NOT (ValuesSettings.Profile, ValuesSettings.AccessKind) IN
	|					(SELECT
	|						ProfileAccessKindsAllDenied.Profile,
	|						ProfileAccessKindsAllDenied.AccessKind
	|					FROM
	|						ProfileAccessKindsAllDenied AS ProfileAccessKindsAllDenied))
	|
	|GROUP BY
	|	ValuesSettings.AccessGroup,
	|	ValuesSettings.AccessValue
	|
	|INDEX BY
	|	ValuesSettings.AccessGroup,
	|	ValuesSettings.AccessValue,
	|	ValueAllowed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ValuesSettings";
	
	QueryText =
	"SELECT
	|	NewData.AccessGroup,
	|	NewData.AccessValue,
	|	NewData.ValueAllowed,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCriterion2"));
	Fields.Add(New Structure("AccessValue"));
	Fields.Add(New Structure("ValueAllowed"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.AccessGroupsValues", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCriterion1:AccessGroups.Ref
		|&AccessGroupFilterCriterion2:OldData.AccessGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.AccessGroupsValues);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FilterDimensions",       "AccessGroup");
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateInformationRegister(Data, HasCurrentChanges);
		If HasCurrentChanges Then
			HasChanges = True;
		EndIf;
		
		If HasCurrentChanges
		   AND AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
			
			// Scheduling access update.
			BlankRefsOfGroupsAndValuesTypes = AccessManagementInternalCached.BlankRefsOfGroupsAndValuesTypes();
			ChangesContent = New ValueTable;
			ChangesContent.Columns.Add("AccessGroup", New TypeDescription("CatalogRef.AccessGroups"));
			ChangesContent.Columns.Add("AccessValuesType", Metadata.DefinedTypes.AccessValue.Type);
			
			For Each Row In Data.EditStringContent Do
				NewRow = ChangesContent.Add();
				NewRow.AccessGroup = Row.AccessGroup;
				NewRow.AccessValuesType = BlankRefsOfGroupsAndValuesTypes.Get(TypeOf(Row.AccessValue));
			EndDo;
			ChangesContent.GroupBy("AccessGroup, AccessValuesType");
			
			AccessManagementInternal.ScheduleAccessUpdateOnChangeAllowedValues(ChangesContent);
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure UpdateDefaultAllowedValues(UsedAccessKinds, AccessGroups = Undefined, HasChanges = Undefined)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.SetParameter("UsedAccessKinds", UsedAccessKinds);
	
	Query.SetParameter("AccessKindsGroupsAndValuesTypes",
		AccessManagementInternalCached.AccessKindsGroupsAndValuesTypes());
	
	TemporaryTablesQueriesText =
	"SELECT
	|	UsedAccessKinds.AccessKind AS AccessKind,
	|	UsedAccessKinds.AccessKindUsers AS AccessKindUsers,
	|	UsedAccessKinds.AccessKindExternalUsers AS AccessKindExternalUsers
	|INTO UsedAccessKinds
	|FROM
	|	&UsedAccessKinds AS UsedAccessKinds
	|
	|INDEX BY
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Purpose.Ref AS Profile,
	|	MIN(VALUETYPE(Purpose.UsersType) = TYPE(Catalog.Users)) AS OnlyForUsers,
	|	MIN(VALUETYPE(Purpose.UsersType) <> TYPE(Catalog.Users)
	|			AND Purpose.UsersType <> UNDEFINED) AS ForExternalUsersOnly
	|INTO ProfilesPurpose
	|FROM
	|	Catalog.AccessGroupProfiles.Purpose AS Purpose
	|
	|GROUP BY
	|	Purpose.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProfilesPurpose.Profile AS Profile,
	|	UsedAccessKinds.AccessKind AS AccessKind,
	|	FALSE AS FalseValue
	|INTO ProfileAccessKindsAllDenied
	|FROM
	|	UsedAccessKinds AS UsedAccessKinds
	|		INNER JOIN ProfilesPurpose AS ProfilesPurpose
	|		ON (UsedAccessKinds.AccessKindUsers
	|					AND NOT ProfilesPurpose.OnlyForUsers
	|				OR UsedAccessKinds.AccessKindExternalUsers
	|					AND NOT ProfilesPurpose.ForExternalUsersOnly)
	|
	|INDEX BY
	|	ProfilesPurpose.Profile,
	|	UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessKindsGroupsAndValuesTypes.AccessKind AS AccessKind,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType AS GroupAndValueType
	|INTO AccessKindsGroupsAndValuesTypes
	|FROM
	|	&AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|
	|INDEX BY
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType,
	|	AccessKindsGroupsAndValuesTypes.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS Ref,
	|	AccessGroups.Profile AS Profile
	|INTO AccessGroups
	|FROM
	|	Catalog.AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles AS AccessGroupProfiles
	|		ON AccessGroups.Profile = AccessGroupProfiles.Ref
	|			AND (AccessGroups.Profile <> VALUE(Catalog.AccessGroupProfiles.Administrator))
	|			AND (NOT AccessGroups.DeletionMark)
	|			AND (NOT AccessGroupProfiles.DeletionMark)
	|			AND (&AccessGroupFilterCriterion1)
	|			AND (TRUE IN
	|				(SELECT TOP 1
	|					TRUE AS TrueValue
	|				FROM
	|					Catalog.AccessGroups.Users AS AccessGroupsMembers
	|				WHERE
	|					AccessGroupsMembers.Ref = AccessGroups.Ref))
	|
	|INDEX BY
	|	AccessGroups.Profile
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	ProfileAccessKinds.AccessKind AS AccessKind,
	|	ProfileAccessKinds.AllAllowed AS AllAllowed
	|INTO AccessKindsSettings
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS ProfileAccessKinds
	|		ON AccessGroups.Profile = ProfileAccessKinds.Ref
	|			AND (ProfileAccessKinds.PresetAccessKind)
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON (ProfileAccessKinds.AccessKind = UsedAccessKinds.AccessKind)
	|
	|UNION ALL
	|
	|SELECT
	|	AccessKinds.Ref,
	|	AccessKinds.AccessKind,
	|	AccessKinds.AllAllowed
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN Catalog.AccessGroups.AccessKinds AS AccessKinds
	|		ON (AccessKinds.Ref = AccessGroups.Ref)
	|		INNER JOIN Catalog.AccessGroupProfiles.AccessKinds AS SpecifiedAccessKinds
	|		ON (SpecifiedAccessKinds.Ref = AccessGroups.Profile)
	|			AND (SpecifiedAccessKinds.AccessKind = AccessKinds.AccessKind)
	|			AND (NOT SpecifiedAccessKinds.PresetAccessKind)
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON (AccessKinds.AccessKind = UsedAccessKinds.AccessKind)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ValuesSettings.AccessGroup AS AccessGroup,
	|	AccessKindsGroupsAndValuesTypes.AccessKind AS AccessKind,
	|	TRUE AS WithSettings
	|INTO HasValueSettings
	|FROM
	|	AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|		INNER JOIN InformationRegister.AccessGroupsValues AS ValuesSettings
	|		ON (VALUETYPE(AccessKindsGroupsAndValuesTypes.GroupAndValueType) = VALUETYPE(ValuesSettings.AccessValue))
	|		INNER JOIN UsedAccessKinds AS UsedAccessKinds
	|		ON AccessKindsGroupsAndValuesTypes.AccessKind = UsedAccessKinds.AccessKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroups.Ref AS AccessGroup,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType AS AccessValuesType,
	|	MAX(ISNULL(ProfileAccessKindsAllDenied.FalseValue, ISNULL(AccessKindsSettings.AllAllowed, TRUE))) AS AllAllowed,
	|	MAX(ISNULL(ProfileAccessKindsAllDenied.FalseValue, AccessKindsSettings.AllAllowed IS NULL)) AS AccessKindNotUsed,
	|	MAX(ISNULL(HasValueSettings.WithSettings, FALSE)) AS WithSettings
	|INTO TemplateForNewData
	|FROM
	|	AccessGroups AS AccessGroups
	|		INNER JOIN AccessKindsGroupsAndValuesTypes AS AccessKindsGroupsAndValuesTypes
	|		ON (TRUE)
	|		LEFT JOIN ProfileAccessKindsAllDenied AS ProfileAccessKindsAllDenied
	|		ON (ProfileAccessKindsAllDenied.Profile = AccessGroups.Profile)
	|			AND (ProfileAccessKindsAllDenied.AccessKind = AccessKindsGroupsAndValuesTypes.AccessKind)
	|		LEFT JOIN AccessKindsSettings AS AccessKindsSettings
	|		ON (AccessKindsSettings.AccessGroup = AccessGroups.Ref)
	|			AND (AccessKindsSettings.AccessKind = AccessKindsGroupsAndValuesTypes.AccessKind)
	|		LEFT JOIN HasValueSettings AS HasValueSettings
	|		ON (HasValueSettings.AccessGroup = AccessKindsSettings.AccessGroup)
	|			AND (HasValueSettings.AccessKind = AccessKindsSettings.AccessKind)
	|
	|GROUP BY
	|	AccessGroups.Ref,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType
	|
	|INDEX BY
	|	AccessGroups.Ref,
	|	AccessKindsGroupsAndValuesTypes.GroupAndValueType
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemplateForNewData.AccessGroup AS AccessGroup,
	|	TemplateForNewData.AccessValuesType AS AccessValuesType,
	|	TemplateForNewData.AllAllowed AS AllAllowed,
	|	CASE
	|		WHEN TemplateForNewData.AllAllowed = TRUE
	|				AND TemplateForNewData.WithSettings = FALSE
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AllAllowedWithoutExceptions,
	|	TemplateForNewData.AccessKindNotUsed AS NoSettings
	|INTO NewData
	|FROM
	|	TemplateForNewData AS TemplateForNewData
	|
	|INDEX BY
	|	TemplateForNewData.AccessGroup,
	|	TemplateForNewData.AccessValuesType,
	|	TemplateForNewData.AllAllowed,
	|	AllAllowedWithoutExceptions,
	|	NoSettings
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP AccessKindsSettings";
	
	QueryText =
	"SELECT
	|	NewData.AccessGroup,
	|	NewData.AccessValuesType,
	|	NewData.AllAllowed,
	|	NewData.AllAllowedWithoutExceptions,
	|	NewData.NoSettings,
	|	&RowChangeKindFieldSubstitution
	|FROM
	|	NewData AS NewData";
	
	// Preparing the selected fields with optional filter.
	Fields = New Array; 
	Fields.Add(New Structure("AccessGroup", "&AccessGroupFilterCriterion2"));
	Fields.Add(New Structure("AccessValuesType"));
	Fields.Add(New Structure("AllAllowed"));
	Fields.Add(New Structure("AllAllowedWithoutExceptions"));
	Fields.Add(New Structure("NoSettings"));
	
	Query.Text = AccessManagementInternal.ChangesSelectionQueryText(
		QueryText, Fields, "InformationRegister.DefaultAccessGroupsValues", TemporaryTablesQueriesText);
	
	AccessManagementInternal.SetFilterCriterionInQuery(Query, AccessGroups, "AccessGroups",
		"&AccessGroupFilterCriterion1:AccessGroups.Ref
		|&AccessGroupFilterCriterion2:OldData.AccessGroup");
	
	Data = New Structure;
	Data.Insert("RegisterManager",      InformationRegisters.DefaultAccessGroupsValues);
	Data.Insert("EditStringContent", Query.Execute().Unload());
	Data.Insert("FilterDimensions",       "AccessGroup");
	
	BeginTransaction();
	Try
		HasCurrentChanges = False;
		AccessManagementInternal.UpdateInformationRegister(Data, HasCurrentChanges);
		If HasCurrentChanges Then
			HasChanges = True;
		EndIf;
		
		If HasCurrentChanges
		   AND AccessManagementInternal.LimitAccessAtRecordLevelUniversally() Then
			
			// Scheduling access update.
			ChangesContent = Data.EditStringContent.Copy(, "AccessGroup, AccessValuesType");
			ChangesContent.GroupBy("AccessGroup, AccessValuesType");
			
			AccessManagementInternal.ScheduleAccessUpdateOnChangeAllowedValues(ChangesContent);
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

#EndRegion

#EndIf
