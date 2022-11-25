#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Modified() And Count() = 0 Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AccountingTransactionGenerationSettings.ScheduledJobUUID AS ScheduledJobUUID
		|FROM
		|	InformationRegister.AccountingTransactionGenerationSettings AS AccountingTransactionGenerationSettings
		|WHERE
		|	AccountingTransactionGenerationSettings.Company = &Company
		|	AND AccountingTransactionGenerationSettings.TypeOfAccounting = &TypeOfAccounting";
		
		Query.SetParameter("Company"			, Filter.Company.Value);
		Query.SetParameter("TypeOfAccounting"	, Filter.TypeOfAccounting.Value);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			
			If ValueIsFilled(SelectionDetailRecords.ScheduledJobUUID) Then
				
				Job = ScheduledJobsServer.Job(SelectionDetailRecords.ScheduledJobUUID);
				
				If Job <> Undefined Then
					ScheduledJobsServer.DeleteJob(Job);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;

EndProcedure

#EndRegion

#EndIf