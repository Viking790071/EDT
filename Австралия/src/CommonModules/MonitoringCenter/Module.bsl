#Region Public

#Region Common

Function MonitoringCenterEnabled() Export
	MonitoringCenterParameters = New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParametersExternalCall(MonitoringCenterParameters);	
	Return MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter;
EndFunction

Procedure EnableSubsystem() Export
    
    MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters();
    
    MonitoringCenterParameters.EnableMonitoringCenter = True;
	MonitoringCenterParameters.ApplicationInformationProcessingCenter = False;
    
    MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(MonitoringCenterParameters);
	ScheduledJob = MonitoringCenterInternal.GetScheduledJobExternalCall("StatisticsDataCollectionAndSending", True);
	MonitoringCenterInternal.SetDefaultScheduleExternalCall(ScheduledJob);
    
EndProcedure

Procedure DisableSubsystem() Export
    
    MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters();
    
    MonitoringCenterParameters.EnableMonitoringCenter = False;
	MonitoringCenterParameters.ApplicationInformationProcessingCenter = False;
	
    MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(MonitoringCenterParameters);
	MonitoringCenterInternal.DeleteScheduledJobExternalCall("StatisticsDataCollectionAndSending");
    
EndProcedure

Function InfoBaseID() Export
	
	ParametersToGet = New Structure;
	ParametersToGet.Insert("EnableMonitoringCenter");
	ParametersToGet.Insert("ApplicationInformationProcessingCenter");
	ParametersToGet.Insert("DiscoveryPackageSent");
	ParametersToGet.Insert("LastPackageNumber");
	ParametersToGet.Insert("InfoBaseID");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(ParametersToGet);
	
	If (MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter) 
		And MonitoringCenterParameters.DiscoveryPackageSent Then
		Return String(MonitoringCenterParameters.InfoBaseID);
	EndIf;
	
	Return "";	
	
EndFunction

#EndRegion

#Region BusinessStatistics

Procedure WriteBusinessStatisticsOperation(OperationName, Value, Comment = Undefined, Separator = ".") Export
	If WriteBusinessStatisticsOperations1() Then
		InformationRegisters.StatisticsOperationsClipboard.WriteBusinessStatisticsOperation(OperationName, Value, Comment, Separator);
	EndIf;
EndProcedure

Procedure WriteBusinessStatisticsOperationHour(OperationName, UniqueKey, Value, Replace = False) Export
    
    WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType, RecordPeriod");
    WriteParameters.OperationName = OperationName;
    WriteParameters.UniqueKey = UniqueKey;
    WriteParameters.Value = Value;
    WriteParameters.Replace = Replace;
    WriteParameters.EntryType = 1;
    WriteParameters.RecordPeriod = BegOfHour(CurrentUniversalDate());
    
    MonitoringCenterInternal.WriteBusinessStatisticsOperationInternal(WriteParameters);
    
EndProcedure

Procedure WriteBusinessStatisticsOperationDay(OperationName, UniqueKey, Value, Replace = False) Export
    
    WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType, RecordPeriod");
    WriteParameters.OperationName = OperationName;
    WriteParameters.UniqueKey = UniqueKey;
    WriteParameters.Value = Value;
    WriteParameters.Replace = Replace;
    WriteParameters.EntryType = 2;
    WriteParameters.RecordPeriod = BegOfDay(CurrentUniversalDate());
   
    MonitoringCenterInternal.WriteBusinessStatisticsOperationInternal(WriteParameters);
    
EndProcedure

Function WriteBusinessStatisticsOperations1() Export
	MonitoringCenterParameters = New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter, RegisterBusinessStatistics");
		
	MonitoringCenterInternal.GetMonitoringCenterParameters(MonitoringCenterParameters);
	
	Return (MonitoringCenterParameters.EnableMonitoringCenter Or MonitoringCenterParameters.ApplicationInformationProcessingCenter) And MonitoringCenterParameters.RegisterBusinessStatistics;
EndFunction

#EndRegion

#Region ConfigurationStatistics

Procedure WriteConfigurationStatistics(MetadataNamesMap) Export
	Parameters = New Map;
	For Each CurMetadata In MetadataNamesMap Do
		Parameters.Insert(CurMetadata.Key, New Structure("Query, StatisticsOperations, StatisticsKind", CurMetadata.Value,,0));
	EndDo;
	
    If Common.DataSeparationEnabled() And Common.SubsystemExists("SaaSTechnology.Core") Then
        ModuleSaaS = Common.CommonModule("SaaS");
        DataAreaString = Format(ModuleSaaS.SessionSeparatorValue(), "NG=0");
    Else
        DataAreaString = "0";
    EndIf;
	DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataAreaString);
	
	InformationRegisters.ConfigurationStatistics.Write(Parameters, DataAreaRef);
EndProcedure

Procedure WriteConfigurationObjectStatistics(ObjectName, Value) Export
    
    If Value <> 0 Then 
        StatisticsOperation = MonitoringCenterCached.GetStatisticsOperationRef(ObjectName);
        
        If Common.DataSeparationEnabled() And Common.SubsystemExists("SaaSTechnology.Core") Then
            ModuleSaaS = Common.CommonModule("SaaS");
            DataAreaString = Format(ModuleSaaS.SessionSeparatorValue(), "NG=0");
        Else
            DataAreaString = "0";
        EndIf;
        DataAreaRef = InformationRegisters.StatisticsAreas.GetRef(DataAreaString);
        
        RecordSet = InformationRegisters.ConfigurationStatistics.CreateRecordSet();
        RecordSet.Filter.StatisticsOperation.Set(StatisticsOperation);
        
        NewRecord1 = RecordSet.Add();
        NewRecord1.StatisticsAreaID = DataAreaRef;
        NewRecord1.StatisticsOperation = StatisticsOperation;
        NewRecord1.Value = Value;	
        RecordSet.Write(True);
    EndIf;
    
EndProcedure

#EndRegion

#EndRegion
