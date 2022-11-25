#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

// Starts data exchange and is used in the background job.
//
// Parameters:
//   JobParameters - Structure - parameters required to execute the procedure.
//   StorageAddress - Row - address of the temporary storage.
//
Procedure StartDataExchangeExecution(JobParameters, StorageAddress) Export
	
	ExchangeParameters = DataExchangeServer.ExchangeParameters();
	
	FillPropertyValues(ExchangeParameters, JobParameters,
		"ExchangeMessagesTransportKind,ExecuteImport,ExecuteExport");
		
	If JobParameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		ExchangeParameters.TimeConsumingOperation          = JobParameters.TimeConsumingOperation;
		ExchangeParameters.TimeConsumingOperationAllowed = True;
		ExchangeParameters.OperationID       = JobParameters.TimeConsumingOperationID;
		ExchangeParameters.FileID          = JobParameters.MessageFileIDInService;
		ExchangeParameters.AuthenticationParameters     = JobParameters.AuthenticationParameters;
	EndIf;
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
		JobParameters.InfobaseNode,
		ExchangeParameters,
		JobParameters.Cancel);
		
	If JobParameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		JobParameters.TimeConsumingOperation                  = ExchangeParameters.TimeConsumingOperation;
		JobParameters.TimeConsumingOperationID     = ExchangeParameters.OperationID;
		JobParameters.AuthenticationParameters             = ExchangeParameters.AuthenticationParameters;
		
		If ValueIsFilled(JobParameters.TimeConsumingOperationID) Then
			// If the job is performed at correspondent, then it will be necessary to import the received file to the database later.
			JobParameters.MessageFileIDInService = ExchangeParameters.FileID;
		Else
			// File with data has already been received and imported to the base, there is no need to import it additionally.
			JobParameters.MessageFileIDInService = "";
		EndIf;
		
	EndIf;
	
	PutToTempStorage(JobParameters, StorageAddress);
	
EndProcedure

// Starts importing a file received from the Internet. It is used in a background job.
//
// Parameters:
//   JobParameters - Structure - parameters required to execute the procedure.
//   StorageAddress - Row - address of the temporary storage.
//
Procedure ImportFileDownloadedFromInternet(JobParameters, StorageAddress) Export
	
	DataExchangeServerCall.ExecuteDataExchangeForInfobaseNodeTimeConsumingOperationCompletion(
		JobParameters.Cancel,
		JobParameters.InfobaseNode,
		JobParameters.MessageFileIDInService,
		JobParameters.OperationStartDate,
		JobParameters.AuthenticationParameters);
		
	JobParameters.MessageFileIDInService = "";
	PutToTempStorage(JobParameters, StorageAddress);
	
EndProcedure

#EndRegion

#EndIf