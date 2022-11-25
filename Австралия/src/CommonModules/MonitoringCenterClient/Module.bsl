#Region Public

#Region PublicBusinessStatistics

Procedure WriteBusinessStatisticsOperation(OperationName, Value) Export
    
    If RegisterBusinessStatistics() Then 
        WriteParameters = New Structure("OperationName,Value, EntryType");
        WriteParameters.OperationName = OperationName;
        WriteParameters.Value = Value;
        WriteParameters.EntryType = 0;
        
        WriteBusinessStatisticsOperationInternal(WriteParameters);
    EndIf;
    
EndProcedure

Procedure WriteBusinessStatisticsOperationHour(OperationName, Value, Replace = False, UniqueKey = Undefined) Export
    
    If RegisterBusinessStatistics() Then
        WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType");
        WriteParameters.OperationName = OperationName;
        WriteParameters.UniqueKey = UniqueKey;
        WriteParameters.Value = Value;
        WriteParameters.Replace = Replace;
        WriteParameters.EntryType = 1;
        
        WriteBusinessStatisticsOperationInternal(WriteParameters);
    EndIf;
    
EndProcedure

Procedure WriteBusinessStatisticsOperationDay(OperationName, Value, Replace = False, UniqueKey = Undefined) Export
    
    If RegisterBusinessStatistics() Then
        WriteParameters = New Structure("OperationName, UniqueKey, Value, Replace, EntryType");
        WriteParameters.OperationName = OperationName;
        WriteParameters.UniqueKey = UniqueKey;
        WriteParameters.Value = Value;
        WriteParameters.Replace = Replace;
        WriteParameters.EntryType = 2;
        
        WriteBusinessStatisticsOperationInternal(WriteParameters);
    EndIf;
    
EndProcedure

#EndRegion

#EndRegion

#Region Private

Procedure WriteBusinessStatisticsOperationInternal(WriteParameters)
    
    MonitoringCenterApplicationParameters = MonitoringCenterClientInternal.GetApplicationParameters();
    Measurements = MonitoringCenterApplicationParameters["Measurements"][WriteParameters.EntryType];
    
    Measurement = New Structure("EntryType, Key, StatisticsOperation, Value, Replace");
    Measurement.EntryType = WriteParameters.EntryType;
    Measurement.StatisticsOperation = WriteParameters.OperationName;
    Measurement.Value = WriteParameters.Value;
    
    If Measurement.EntryType = 0 Then
        
        Measurements.Add(Measurement);
        
    Else
        
        If WriteParameters.UniqueKey = Undefined Then
            Measurement.Key = MonitoringCenterApplicationParameters["ClientInformation"]["ClientParameters1"]["UserHash"];
        Else
            Measurement.Key = WriteParameters.UniqueKey;
        EndIf;
        
        Measurement.Replace = WriteParameters.Replace;
        
        If Not (Measurements[Measurement.Key] <> Undefined And Not Measurement.Replace) Then
            Measurements.Insert(Measurement.Key, Measurement);
        EndIf;
        
    EndIf;
        
EndProcedure

Function  RegisterBusinessStatistics()
	
	ParameterName = "StandardSubsystems.MonitoringCenter";
	
	If ApplicationParameters[ParameterName] = Undefined Then
		ApplicationParameters.Insert(ParameterName, MonitoringCenterClientInternal.GetApplicationParameters());
	EndIf;
	
	Return ApplicationParameters[ParameterName]["RegisterBusinessStatistics"];
	
EndFunction

Procedure AfterUpdateID(Result, AdditionalParameters) Export
	If Result <> Undefined Then
		Notify("IDUpdateMonitoringCenter", Result);
	EndIf;	
EndProcedure

#EndRegion