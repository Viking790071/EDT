#Region Public

Function CheckQuotationStatusToConverted(QuotationRef) Export
	
	Result = False;
	
	If ValueIsFilled(QuotationRef) And TypeOf(QuotationRef) = Type("DocumentRef.Quote") Then
		
		QuoteStatus = GetQuotationStatus(QuotationRef);
		If QuoteStatus <> Catalogs.QuotationStatuses.Closed And QuoteStatus <> Catalogs.QuotationStatuses.Converted Then
			Result = True;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetQuotationDefaultStatus() Export
	
	Result = Catalogs.QuotationStatuses.EmptyRef();
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	QuotationStatuses.Ref AS Status
	|FROM
	|	Catalog.QuotationStatuses AS QuotationStatuses
	|WHERE
	|	NOT QuotationStatuses.Disabled
	|	AND NOT QuotationStatuses.DeletionMark
	|
	|ORDER BY
	|	QuotationStatuses.Order";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = Selection.Status;
	EndIf;
	
	Return Result;
	
EndFunction

Function GetQuotationStatus(QuotationRef) Export
	
	Result = Catalogs.QuotationStatuses.EmptyRef();
	
	If ValueIsFilled(QuotationRef) And TypeOf(QuotationRef) = Type("DocumentRef.Quote") Then
		
		Query = New Query;
		Query.SetParameter("QuotationRef", QuotationRef);
		Query.Text = 
		"SELECT
		|	QuotationKanbanStatuses.Status AS Status
		|FROM
		|	InformationRegister.QuotationKanbanStatuses.SliceLast(, Quotation = &QuotationRef) AS QuotationKanbanStatuses";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			Result = Selection.Status;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure SetQuotationStatus(QuotationRef, NewStatus) Export
	
	If ValueIsFilled(QuotationRef)
		And TypeOf(QuotationRef) = Type("DocumentRef.Quote")
		And ValueIsFilled(NewStatus)
		And TypeOf(NewStatus) = Type("CatalogRef.QuotationStatuses") Then
		
		Status = GetQuotationStatus(QuotationRef);
		If Not ValueIsFilled(Status) Or Status <> NewStatus Then
			
			RecordManager = InformationRegisters.QuotationKanbanStatuses.CreateRecordManager();
			RecordManager.Quotation = QuotationRef;
			RecordManager.Status = NewStatus;
			RecordManager.Period = CurrentSessionDate();
			RecordManager.Write();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion