#Region Internal

// Returns the earliest infobase version used across all data areas.
//
// Returns:
//  String - for example, "2.3.1.4".
//
Function EarliestIBVersion() Export
	
	If Common.DataSeparationEnabled() Then
		
		ModuleInfobaseUpdateInternalSaaS = Common.CommonModule(
			"InfobaseUpdateInternalSaaS");
		
		EarliestDataAreaVersion = ModuleInfobaseUpdateInternalSaaS.EarliestDataAreaVersion();
	Else
		EarliestDataAreaVersion = Undefined;
	EndIf;
	
	IBVersion = InfobaseUpdateInternal.IBVersion(Metadata.Name);
	
	If EarliestDataAreaVersion = Undefined Then
		EarliestIBVersion = IBVersion;
	Else
		If CommonClientServer.CompareVersions(IBVersion, EarliestDataAreaVersion) > 0 Then
			EarliestIBVersion = EarliestDataAreaVersion;
		Else
			EarliestIBVersion = IBVersion;
		EndIf;
	EndIf;
	
	Return EarliestIBVersion;
	
EndFunction

#EndRegion

#Region Private

// Checks if the infobase update is required when the configuration version is changed.
//
Function InfobaseUpdateRequired() Export
	
	If InfobaseUpdateInternal.UpdateRequired(
			Metadata.Version, InfobaseUpdateInternal.IBVersion(Metadata.Name)) Then
		Return True;
	EndIf;
	
	If Not InfobaseUpdateInternal.DeferredUpdateHandlersRegistered() Then
		Return True;
	EndIf;
	
	SetPrivilegedMode(True);
	Run = SessionParameters.ClientParametersAtServer.Get("StartInfobaseUpdate");
	SetPrivilegedMode(False);
	
	If Run <> Undefined AND InfobaseUpdateInternal.CanUpdateInfobase() Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Returns the map of names and IDs for deferred handlers and handler queues.
// 
Function DeferredUpdateHandlerQueue() Export
	
	Handlers        = InfobaseUpdate.NewUpdateHandlerTable();
	SubsystemsDetails  = StandardSubsystemsCached.SubsystemsDetails();
	For Each SubsystemName In SubsystemsDetails.Order Do
		SubsystemDetails = SubsystemsDetails.ByNames.Get(SubsystemName);
		If SubsystemDetails.DeferredHandlerExecutionMode <> "Parallel" Then
			Continue;
		EndIf;
		
		Module = Common.CommonModule(SubsystemDetails.MainServerModule);
		Module.OnAddUpdateHandlers(Handlers);
	EndDo;
	
	Filter = New Structure;
	Filter.Insert("ExecutionMode", "Deferred");
	DeferredHandlers = Handlers.FindRows(Filter);
	
	QueueByName          = New Map;
	QueueByID = New Map;
	For Each DeferredHandler In DeferredHandlers Do
		If DeferredHandler.DeferredProcessingQueue = 0 Then
			Continue;
		EndIf;
		
		QueueByName.Insert(DeferredHandler.Procedure, DeferredHandler.DeferredProcessingQueue);
		If ValueIsFilled(DeferredHandler.ID) Then
			QueueByID.Insert(DeferredHandler.ID, DeferredHandler.DeferredProcessingQueue);
		EndIf;
	EndDo;
	
	Result = New Map;
	Result.Insert("ByName", QueueByName);
	Result.Insert("ByID", QueueByID);
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion
