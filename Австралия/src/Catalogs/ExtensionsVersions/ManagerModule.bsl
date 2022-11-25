#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure SessionParametersSetting(SessionParametersNames, SpecifiedParameters) Export
	
	If SessionParametersNames = Undefined
	 Or SessionParametersNames.Find("InstalledExtensions") <> Undefined Then
		
		SessionParameters.InstalledExtensions = InstalledExtensions();
		SpecifiedParameters.Add("InstalledExtensions");
	EndIf;
	
	If SessionParametersNames = Undefined
	 Or SessionParametersNames.Find("AttachedExtensions") <> Undefined Then
		
		Extensions = ConfigurationExtensions.Get(, ConfigurationExtensionsSource.SessionApplied);
		SessionParameters.AttachedExtensions = ExtensionsChecksums(Extensions);
		SpecifiedParameters.Add("AttachedExtensions");
	EndIf;
	
	If SessionParametersNames <> Undefined
	   AND SessionParametersNames.Find("ExtensionsVersion") <> Undefined Then
		
		SessionParameters.ExtensionsVersion = ExtensionsVersion();
		SpecifiedParameters.Add("ExtensionsVersion");
	EndIf;
	
	If SessionParametersNames = Undefined
	   AND CurrentRunMode() <> Undefined Then
	
		RegisterExtensionsVersionUsage();
	EndIf;
	
EndProcedure

// Returns checksums for the main extensions and patches required for setting the 
// InstalledExtensions session parameter and making further checks for changes.
// 
// 
// It is called at the startup to set the InstalledExtensions session parameter, which is required 
// to perform the extension availability check and to manage dynamic updates, and also from the 
// configuration extensions setup form in 1C:Enterprise mode.
//
// In a shared session, returns only shared extensions, regardless of the specified separators.
// 
//
// Returns:
//  FixedStructure - with the following properties:
//   * Main    - String - a checksum of all extensions except for patch extensions.
//   * Patches - String - a checksum of all patch extensions.
//
Function InstalledExtensions() Export
	
	If Common.DataSeparationEnabled()
	   AND Common.SubsystemExists("StandardSubsystems.SaaS") Then
		
		ModuleSaaS = Common.CommonModule("SaaS");
		Shared = ModuleSaaS.SessionWithoutSeparators();
	Else
		Shared = False;
	EndIf;
	
	Extensions = ConfigurationExtensions.Get();
	
	Main    = New Array;
	Patches = New Array;
	
	If Common.SubsystemExists("StandardSubsystems.ConfigurationUpdate") Then 
		ModuleSoftwareUpdate = Common.CommonModule("ConfigurationUpdate");
		For Each Extension In Extensions Do
			If Shared AND Extension.Scope = ConfigurationExtensionScope.DataSeparation Then
				Continue;
			EndIf;
			If ModuleSoftwareUpdate.IsPatch(Extension) Then 
				Patches.Add(Extension);
			Else
				Main.Add(Extension);
			EndIf;
		EndDo;
	Else
		Main = Extensions;
	EndIf;
	
	InstalledExtensions = New Structure;
	InstalledExtensions.Insert("Main",    ExtensionsChecksums(Main));
	InstalledExtensions.Insert("Patches", ExtensionsChecksums(Patches));
	
	Return New FixedStructure(InstalledExtensions);
	
EndFunction

// Returns a flag that shows whether the extension content was changed after the session start.
Function ExtensionsChangedDynamically() Export
	
	SetPrivilegedMode(True);
	
	InstalledExtensions = InstalledExtensions();
	
	Return SessionParameters.InstalledExtensions.Main    <> InstalledExtensions.Main
	    Or SessionParameters.InstalledExtensions.Patches <> InstalledExtensions.Patches;
	
EndFunction

// Adds information that the session started using the metadata version.
Procedure RegisterExtensionsVersionUsage() Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	ExtensionsVersion = SessionParameters.ExtensionsVersion;
	
	If Not ValueIsFilled(ExtensionsVersion) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 2
	|	TRUE AS TrueValue
	|FROM
	|	Catalog.ExtensionsVersions AS ExtensionsVersions";
	
	// If the catalog is being changed in another session, waiting for the completion.
	Lock = New DataLock;
	LockItem = Lock.Add("Catalog.ExtensionsVersions");
	LockItem.Mode = DataLockMode.Shared;
	
	BeginTransaction();
	Try
		Lock.Lock();
		QueryResults = Query.ExecuteBatch();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If QueryResults[0].Select().Count() < 2 Then
		UpdateLatestExtensionsVersion(ExtensionsVersion);
		Return;
	EndIf;
	
	CurrentSession = GetCurrentInfoBaseSession();
	SessionStart = CurrentSession.SessionStarted;
	SessionNumber  = CurrentSession.SessionNumber;
	
	RecordSet = InformationRegisters.ExtensionVersionSessions.CreateRecordSet();
	RecordSet.Filter.SessionNumber.Set(SessionNumber);
	RecordSet.Filter.SessionStarted.Set(SessionStart);
	RecordSet.Filter.ExtensionsVersion.Set(ExtensionsVersion);
	
	NewRecord = RecordSet.Add();
	NewRecord.SessionNumber      = SessionNumber;
	NewRecord.SessionStarted     = SessionStart;
	NewRecord.ExtensionsVersion = ExtensionsVersion;
	
	RecordSet.DataExchange.Load = True;
	RecordSet.Write();
	
	UpdateLatestExtensionsVersion(ExtensionsVersion);
	
EndProcedure

Function LastExtensionsVersion() Export
	
	ParameterName = "StandardSubsystems.Core.LastExtensionsVersion";
	StoredProperties = StandardSubsystemsServer.ExtensionParameter(ParameterName, True);
	
	If StoredProperties = Undefined
	 Or TypeOf(StoredProperties) <> Type("Structure")
	 Or Not StoredProperties.Property("ExtensionsVersion")
	 Or Not StoredProperties.Property("UpdateDate") Then
		
		StoredProperties = New Structure("ExtensionsVersion, UpdateDate", , '00010101');
	EndIf;
	
	Return StoredProperties;
	
EndFunction

// Deletes obsolete metadata versions.
Procedure DeleteObsoleteParametersVersions() Export
	
	Query = New Query;
	Query.SetParameter("CurrentExtensionsVersion", SessionParameters.ExtensionsVersion);
	Query.Text =
	"SELECT
	|	ExtensionsVersions.Ref AS ExtensionsVersion,
	|	ExtensionVersionSessions.SessionNumber AS SessionNumber,
	|	ExtensionVersionSessions.SessionStarted AS SessionStarted
	|FROM
	|	Catalog.ExtensionsVersions AS ExtensionsVersions
	|		LEFT JOIN InformationRegister.ExtensionVersionSessions AS ExtensionVersionSessions
	|		ON (ExtensionVersionSessions.ExtensionsVersion = ExtensionsVersions.Ref)
	|WHERE
	|	ExtensionsVersions.Ref <> &CurrentExtensionsVersion
	|TOTALS BY
	|	ExtensionsVersion
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	ExtensionsVersions.Ref AS ExtensionsVersion,
	|	ExtensionsVersions.LastSecondVersionAddingDate
	|FROM
	|	Catalog.ExtensionsVersions AS ExtensionsVersions
	|WHERE
	|	ExtensionsVersions.LastSecondVersionAddingDate <> DATETIME(1, 1, 1, 0, 0, 0)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	ExtensionsVersions.Ref AS ExtensionsVersion,
	|	ExtensionsVersions.DateOfFirstAuthorizationAfterDeleteAllExtensions
	|FROM
	|	Catalog.ExtensionsVersions AS ExtensionsVersions
	|WHERE
	|	ExtensionsVersions.DateOfFirstAuthorizationAfterDeleteAllExtensions <> DATETIME(1, 1, 1, 0, 0, 0)";
	
	// If the ExtensionsVersions catalog or the ExtensionsVersionSessions information register is being 
	// changed in another session, waiting for the completion.
	Lock = New DataLock;
	LockItem = Lock.Add("Catalog.ExtensionsVersions");
	LockItem.Mode = DataLockMode.Shared;
	LockItem = Lock.Add("InformationRegister.ExtensionVersionSessions");
	LockItem.Mode = DataLockMode.Shared;
	
	BeginTransaction();
	Try
		Lock.Lock();
		QueryResults = Query.ExecuteBatch();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	DataExported = QueryResults[0].Unload(QueryResultIteration.ByGroups);
	
	SessionsArray = GetInfoBaseSessions();
	
	// A version that was the first when adding the second version (at the beginning or after deletion 
	// of obsolete versions) can be used by sessions that were open before the event.
	// 
	VersionInUseInUnregisteredSessions = Undefined;
	EndDateOfSessionsUsingExtensionsWithoutRegistration = '00010101';
	
	If ValueIsFilled(SessionParameters.InstalledExtensions.Main)
	 Or ValueIsFilled(SessionParameters.InstalledExtensions.Patches) Then
		
		If Not QueryResults[1].IsEmpty() Then
			Properties = QueryResults[1].Unload()[0];
			EndDateOfSessionsUsingExtensionsWithoutRegistration
				= Properties.LastSecondVersionAddingDate;
			FirstVersion = Properties.ExtensionsVersion;
		EndIf;
	Else
		If Not QueryResults[2].IsEmpty() Then
			Properties = QueryResults[2].Unload()[0];
			EndDateOfSessionsUsingExtensionsWithoutRegistration
				= Properties.DateOfFirstAuthorizationAfterDeleteAllExtensions;
			FirstVersion = Properties.ExtensionsVersion;
		EndIf;
	EndIf;
	
	ApplicationsToCheck = New Map;
	ApplicationsToCheck.Insert("1CV8", True);
	ApplicationsToCheck.Insert("1CV8C", True);
	ApplicationsToCheck.Insert("WebClient", True);
	ApplicationsToCheck.Insert("COMConnection", True);
	ApplicationsToCheck.Insert("WSConnection", True);
	ApplicationsToCheck.Insert("BackgroundJob", True);
	ApplicationsToCheck.Insert("SystemBackgroundJob", True);
	
	Sessions = New Map;
	For Each Session In SessionsArray Do
		If ApplicationsToCheck.Get(Session.ApplicationName) = Undefined Then
			Continue;
		EndIf;
		Sessions.Insert(Session.SessionNumber, Session.SessionStarted);
		If Session.SessionStarted < EndDateOfSessionsUsingExtensionsWithoutRegistration Then
			VersionInUseInUnregisteredSessions = FirstVersion;
		EndIf;
	EndDo;
	
	// Deleting obsolete metadata versions.
	HasDeletedVersions = False;
	For Each VersionDetails In DataExported.Rows Do
		VersionIsInUse = False;
		For Each Row In VersionDetails.Rows Do
			If SessionExists(Row, Sessions) Then
				VersionIsInUse = True;
				Break;
			EndIf;
		EndDo;
		CurrentVersion = VersionDetails.ExtensionsVersion;
		If VersionIsInUse
		 Or CurrentVersion = VersionInUseInUnregisteredSessions Then
			Continue;
		EndIf;
		Object = CurrentVersion.GetObject();
		Object.Delete();
		HasDeletedVersions = True;
	EndDo;
	
	// Disabling the scheduled job if only one extension version is left.
	
	// The efficient way is to apply a full shared lock to the ExtensionsVersions catalog and the 
	// ExtensionsVersionsSessions information register. Applying an exclusive lock is not recommended as 
	// it will delay signing in to other sessions.
	// Shared locks applied to the entire table eliminate deadlocks. It is necessary for registering 
	// extension versions.
	Lock = New DataLock;
	LockItem = Lock.Add("Catalog.ExtensionsVersions");
	LockItem.Mode = DataLockMode.Shared;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 2
	|	ExtensionsVersions.Ref AS Ref,
	|	ExtensionsVersions.DateOfFirstAuthorizationAfterDeleteAllExtensions
	|FROM
	|	Catalog.ExtensionsVersions AS ExtensionsVersions";
	
	BeginTransaction();
	Try
		Lock.Lock();
		DataExported = Query.Execute().Unload();
		If DataExported.Count() < 2 Then
			If DataExported.Count() = 0 Then
				EnableDeleteObsoleteExtensionsVersionsParametersJob(False);
			Else
				// Deleting all metadata usage registrations.
				AllRecords = InformationRegisters.ExtensionVersionSessions.CreateRecordSet();
				AllRecords.Write();
				
				If ValueIsFilled(SessionParameters.InstalledExtensions.Main)
				 Or ValueIsFilled(SessionParameters.InstalledExtensions.Patches) Then
					
					EnableDeleteObsoleteExtensionsVersionsParametersJob(False);
				EndIf;
				If HasDeletedVersions
				   AND ValueIsFilled(DataExported[0].DateOfFirstAuthorizationAfterDeleteAllExtensions) Then
					
					Object = DataExported[0].Ref.GetObject();
					Object.DateOfFirstAuthorizationAfterDeleteAllExtensions = Undefined;
					Object.Write();
				EndIf;
			EndIf;
		Else
			// Deleting obsolete metadata usage registrations.
			AllRecords = InformationRegisters.ExtensionVersionSessions.CreateRecordSet();
			AllRecords.Read();
			
			For Each Row In AllRecords Do
				If SessionExists(Row, Sessions) Then
					Continue;
				EndIf;
				RecordSet = InformationRegisters.ExtensionVersionSessions.CreateRecordSet();
				RecordSet.Filter.SessionNumber.Set(Row.SessionNumber);
				RecordSet.Filter.SessionStarted.Set(Row.SessionStarted);
				RecordSet.Filter.ExtensionsVersion.Set(Row.ExtensionsVersion);
				RecordSet.Write();
			EndDo;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// This procedure is called from an extension form.
Procedure OnRemoveAllExtensions() Export
	
	RegisterFirstAuthorizationAfterAllExtensionsRemoved();
	EnableDeleteObsoleteExtensionsVersionsParametersJob(True);
	
EndProcedure

// Enables and disables the DeleteObsoleteExtensionsVersionsParameters scheduled job.
Procedure EnableDeleteObsoleteExtensionsVersionsParametersJob(Enable) Export
	
	ScheduledJobsServer.SetPredefinedScheduledJobUsage(
		Metadata.ScheduledJobs.DeleteObsoleteExtensionsVersionsParameters, Enable);
	
EndProcedure

#EndRegion

#Region Private

// Returns the checksums of the specified extensions.
//
// Parameters:
//  Extensions - Array - the extensions.
//
// Returns:
//  String - strings of the following format: "<Extension name> (<Extension version>) <Checksum>".
//
Function ExtensionsChecksums(Extensions)
	
	List = New ValueList;
	
	For Each Extension In Extensions Do
		Checksum = Base64String(Extension.HashSum);
		List.Add(Extension.Name + " (" + Extension.Version + ") " + Checksum);
	EndDo;
	
	If List.Count() <> 0 Then
		List.Add("#" + Metadata.Name + " (" + Metadata.Version + ")");
	EndIf;
	
	Checksums = "";
	For Each Item In List Do
		Checksums = Checksums + Chars.LF + Item.Value;
	EndDo;
	
	Return TrimL(Checksums);
	
EndFunction

// Returns the current extensions version.
// The search for version is based on details of attached extensions.
//
Function ExtensionsVersion()
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return EmptyRef();
	EndIf;
	
	If Not ValueIsFilled(SessionParameters.InstalledExtensions.Main)
	   AND Not ValueIsFilled(SessionParameters.InstalledExtensions.Patches) Then
		
		RegisterFirstAuthorizationAfterAllExtensionsRemoved();
	EndIf;
	
	ExtensionsDetails = SessionParameters.AttachedExtensions;
	If Not ValueIsFilled(ExtensionsDetails) Then
		Return EmptyRef();
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ExtensionsVersions.Ref AS Ref,
	|	ExtensionsVersions.MetadataDetails AS ExtensionsDetails
	|FROM
	|	Catalog.ExtensionsVersions AS ExtensionsVersions";
	
	// If the catalog is being changed in another session, waiting for the completion.
	Lock = New DataLock;
	LockItem = Lock.Add("Catalog.ExtensionsVersions");
	LockItem.Mode = DataLockMode.Shared;
	BeginTransaction();
	Try
		Lock.Lock();
		Selection = Query.Execute().Select();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If VersionFound(Selection, ExtensionsDetails) Then
		ExtensionsVersion = Selection.Ref;
	Else
		// Creating an extensions version.
		Lock = New DataLock;
		LockItem = Lock.Add("Catalog.ExtensionsVersions");
		BeginTransaction();
		Try
			// Double checking that the version was not created, which is unlikely but still possible between 
			// transactions.
			// An exclusive lock is unacceptable, as it will delay signing in to other sessions.
			// 
			Selection = Query.Execute().Select();
			If VersionFound(Selection, ExtensionsDetails) Then
				ExtensionsVersion = Selection.Ref;
			Else
				Lock.Lock();
				Query = New Query;
				Query.Text =
				"SELECT
				|	ExtensionsVersions.Ref AS Ref
				|FROM
				|	Catalog.ExtensionsVersions AS ExtensionsVersions";
				Selection = Query.Execute().Select();
				If Selection.Next() AND Selection.Count() = 1 Then
					Object = Selection.Ref.GetObject();
					// Only CurrentDate() can be here as it is set in the SessionStart field.
					// 
					Object.LastSecondVersionAddingDate = CurrentDate();
					Object.DataExchange.Load = True;
					Object.Write();
					EnableDeleteObsoleteExtensionsVersionsParametersJob(True);
				EndIf;
				Object = CreateItem();
				Object.MetadataDetails = ExtensionsDetails;
				Object.DataExchange.Load = True;
				Object.Write();
				ExtensionsVersion = Object.Ref;
			EndIf;
			CommitTransaction();
		Except
			RollbackTransaction();
			Raise;
		EndTry;
	EndIf;
	
	Return ExtensionsVersion;
	
EndFunction

// This method is required by ExtensionsVersion function.
Function VersionFound(Selection, ExtensionsDetails)
	
	While Selection.Next() Do
		If Selection.ExtensionsDetails = ExtensionsDetails Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// This method is required by DeleteObsoleteParametersVersions procedure.
Function SessionExists(SessionDetails, ExistingSessions)
	
	SessionStart = ExistingSessions[SessionDetails.SessionNumber];
	
	Return SessionStart <> Undefined
	      AND SessionStart > (SessionDetails.SessionStarted - 30)
	      AND (SessionDetails.SessionStarted + 30) > SessionStart;
	
EndFunction

// For the ExtensionVersion function and the OnRemoveAllExtensions procedure.
Procedure RegisterFirstAuthorizationAfterAllExtensionsRemoved()
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 2
	|	ExtensionsVersions.Ref AS Ref,
	|	ExtensionsVersions.DateOfFirstAuthorizationAfterDeleteAllExtensions
	|FROM
	|	Catalog.ExtensionsVersions AS ExtensionsVersions";
	DataExported = Query.Execute().Unload();
	
	If DataExported.Count() = 1
	   AND Not ValueIsFilled(DataExported[0].DateOfFirstAuthorizationAfterDeleteAllExtensions) Then
		
		Object = DataExported[0].Ref.GetObject();
		// Only CurrentDate() can be here as it is set in the SessionStart field.
		// 
		Object.DateOfFirstAuthorizationAfterDeleteAllExtensions = CurrentDate();
		Object.Write();
	EndIf;
	
EndProcedure

// This method is required by RegisterExtensionsVersionUsage procedure.
Procedure UpdateLatestExtensionsVersion(ExtensionsVersion)
	
	If DataBaseConfigurationChangedDynamically() Then
		Return;
	EndIf;
	
	StoredProperties = LastExtensionsVersion();
	
	If StoredProperties.ExtensionsVersion = ExtensionsVersion Then
		Return;
	EndIf;
	
	StoredProperties.ExtensionsVersion = ExtensionsVersion;
	StoredProperties.UpdateDate   = CurrentSessionDate();
	
	ParameterName = "StandardSubsystems.Core.LastExtensionsVersion";
	StandardSubsystemsServer.SetExtensionParameter(ParameterName, StoredProperties, True);
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagementInternal = Common.CommonModule("AccessManagementInternal");
		ModuleAccessManagementInternal.SetAccessUpdate(True);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf