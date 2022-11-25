#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure WriteEventLogErrorsStatistics(MonitoringCenterParameters) Export
	
	ServerTimeOffset = EventLogOperations.ServerTimeOffset();
	EventLogErrorsNextGeneration = MonitoringCenterParameters.EventLogErrorsNextGeneration;
	EventLogErrorsGenerationPeriod = MonitoringCenterParameters.EventLogErrorsGenerationPeriod;
	EventLogErrorsEvents = MonitoringCenterParameters.EventLogErrorsEvents;
	
	Filter = New Structure;
	Filter.Insert("StartDate", EventLogErrorsNextGeneration - EventLogErrorsGenerationPeriod + ServerTimeOffset);
	Filter.Insert("EndDate", EventLogErrorsNextGeneration + ServerTimeOffset);
	Filter.Insert("Level", EventLogLevel.Error);
	
	If (TypeOf(EventLogErrorsEvents) = Type("Array") And EventLogErrorsEvents.Count() > 0)
		Or (TypeOf(EventLogErrorsEvents) = Type("String") And EventLogErrorsEvents <> "") Then
		
		Filter.Insert("Event", EventLogErrorsEvents);
		
	EndIf;
	
	EventLogs = New ValueTable;
	UnloadEventLog(EventLogs, Filter, "Date,Event,Comment", , MonitoringCenterParameters.EventLogErrorsCount);
	
	If EventLogs.Count() Then
		RecordSet = CreateRecordSet();
		
		For Each Row In EventLogs Do
			NewRecord = RecordSet.Add();
			NewRecord.ErrorDate = Row.Date;
			NewRecord.Event = Row.Event;
			NewRecord.Comment = Row.Comment;
		EndDo;
		
		RecordSet.Write(False);
	EndIf;
	
EndProcedure

Function GetStatistics() Export
	
	MCParameters = New Structure("EventLogErrorsNextGeneration, EventLogErrorsGenerationPeriod");
	MCParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(MCParameters);
	
	ServerTimeOffset = EventLogOperations.ServerTimeOffset();
	
	Query = New Query;
	Query.Text = "SELECT
	|	StatisticsEventLogErrors.ErrorDate AS ErrorDate,
	|	StatisticsEventLogErrors.Event AS Event,
	|	StatisticsEventLogErrors.Comment AS Comment
	|FROM
	|	InformationRegister.StatisticsEventLogErrors AS StatisticsEventLogErrors
	|WHERE
	|	StatisticsEventLogErrors.ErrorDate > &StartDate";
	
	Query.SetParameter("StartDate", MCParameters.EventLogErrorsNextGeneration - MCParameters.EventLogErrorsGenerationPeriod + ServerTimeOffset);
	QueryResult = Query.Execute();
	
	Return QueryResult;
	
EndFunction

#EndRegion

#EndIf