#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Procedure RecordIssueResolved(Source, IssueType) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If Source.IsNew() Then
		Return;
	EndIf;
	
	If Common.SeparatedDataUsageAvailable() Then
		
		RefToSource = Source.Ref;
		
		DeletionMarkNewValue = Source.DeletionMark;
		
		DataExchangeServerCall.RecordIssueResolved(RefToSource, IssueType, DeletionMarkNewValue);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure RecordDocumentCheckError(Ref, InfobaseNode, Reason, IssueType) Export
	
	ConflictRecordSet = CreateRecordSet();
	ConflictRecordSet.Filter.ObjectWithIssue.Set(Ref);
	ConflictRecordSet.Filter.IssueType.Set(IssueType);
	
	ConflictRecord = ConflictRecordSet.Add();
	ConflictRecord.ObjectWithIssue = Ref;
	ConflictRecord.IssueType = IssueType;
	ConflictRecord.InfobaseNode = InfobaseNode;
	ConflictRecord.OccurrenceDate = CurrentSessionDate();
	ConflictRecord.Reason = TrimAll(Reason);
	ConflictRecord.Skipped = False;
	
	If IssueType = Enums.DataExchangeIssuesTypes.UnpostedDocument Then
		
		If Ref.Metadata().NumberLength > 0 Then
			AttributeValues = Common.ObjectAttributesValues(Ref, "DeletionMark, Number, Date");
			
			ConflictRecord.DocumentNumber  = AttributeValues.Number;
		Else
			AttributeValues = Common.ObjectAttributesValues(Ref, "DeletionMark, Date");
		EndIf;
		
		ConflictRecord.DocumentDate   = AttributeValues.Date;
		ConflictRecord.DeletionMark = AttributeValues.DeletionMark;
		
	Else
		
		ConflictRecord.DeletionMark = Common.ObjectAttributeValue(Ref, "DeletionMark");
		
	EndIf;
	
	ConflictRecordSet.Write();
	
EndProcedure

Procedure Ignore(Ref, IssueType, Ignore) Export
	
	ConflictRecordSet = CreateRecordSet();
	ConflictRecordSet.Filter.ObjectWithIssue.Set(Ref);
	ConflictRecordSet.Filter.IssueType.Set(IssueType);
	ConflictRecordSet.Read();
	ConflictRecordSet[0].Skipped = Ignore;
	ConflictRecordSet.Write();
	
EndProcedure

Function IssueSearchParameters() Export
	
	Parameters = New Structure;
	Parameters.Insert("IssueType",                Undefined);
	Parameters.Insert("IncludingIgnored", False);
	Parameters.Insert("Period",                     Undefined);
	Parameters.Insert("SearchString",               "");
	
	Return Parameters;
	
EndFunction

Function IssuesCount(ExchangeNodes = Undefined, SearchParameters = Undefined) Export
	
	If SearchParameters = Undefined Then
		SearchParameters = IssueSearchParameters();
	EndIf;
	
	Quantity = 0;
	
	QueryText = "SELECT
	|	COUNT(DataExchangeResults.ObjectWithIssue) AS IssuesCount
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	DataExchangeResults.Skipped <> &FilterBySkipped
	|	[FilterByNode]
	|	[FIlterByType]
	|	[FilterByPeriod]
	|	[FilterByReason]";
	
	Query = New Query;
	
	FilterBySkipped = ?(SearchParameters.IncludingIgnored, Undefined, True);
	Query.SetParameter("FilterBySkipped", FilterBySkipped);
	
	If SearchParameters.IssueType = Undefined Then
		FIlterRow = "";
	Else
		FIlterRow = "AND DataExchangeResults.IssueType = &IssueType";
		Query.SetParameter("IssueType", SearchParameters.IssueType);
	EndIf;
	QueryText = StrReplace(QueryText, "[FIlterByType]", FIlterRow);
	
	If ExchangeNodes = Undefined Then
		FIlterRow = "";
	ElsIf ExchangePlans.AllRefsType().ContainsType(TypeOf(ExchangeNodes)) Then
		FIlterRow = "AND DataExchangeResults.InfobaseNode = &InfobaseNode";
		Query.SetParameter("InfobaseNode", ExchangeNodes);
	Else
		FIlterRow = "AND DataExchangeResults.InfobaseNode IN (&ExchangeNodes)";
		Query.SetParameter("ExchangeNodes", ExchangeNodes);
	EndIf;
	
	QueryText = StrReplace(QueryText, "[FilterByNode]", FIlterRow);
	
	If ValueIsFilled(SearchParameters.Period) Then
		
		FIlterRow = "AND (DataExchangeResults.OccurrenceDate >= &StartDate
		| AND DataExchangeResults.OccurrenceDate <= &EndDate)";
		Query.SetParameter("StartDate", SearchParameters.Period.StartDate);
		Query.SetParameter("EndDate", SearchParameters.Period.EndDate);
		
	Else
		
		FIlterRow = "";
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByPeriod]", FIlterRow);
	
	If ValueIsFilled(SearchParameters.SearchString) Then
		
		FIlterRow = "AND DataExchangeResults.Reason LIKE &Reason";
		Query.SetParameter("Reason", "%" + SearchParameters.SearchString + "%");
		
	Else
		
		FIlterRow = "";
		
	EndIf;
	QueryText = StrReplace(QueryText, "[FilterByReason]", FIlterRow);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		Quantity = Selection.IssuesCount;
		
	EndIf;
	
	Return Quantity;
	
EndFunction

Procedure ClearRefsToInfobaseNode(Val InfobaseNode) Export
	
	If Not Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeResults.ObjectWithIssue,
	|	DataExchangeResults.IssueType,
	|	UNDEFINED AS InfobaseNode,
	|	DataExchangeResults.OccurrenceDate,
	|	DataExchangeResults.Reason,
	|	DataExchangeResults.Skipped,
	|	DataExchangeResults.DeletionMark,
	|	DataExchangeResults.DocumentNumber,
	|	DataExchangeResults.DocumentDate
	|FROM
	|	InformationRegister.DataExchangeResults AS DataExchangeResults
	|WHERE
	|	DataExchangeResults.InfobaseNode = &InfobaseNode";
	
	Query.SetParameter("InfobaseNode", InfobaseNode);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		RecordSet = CreateRecordSet();
		
		RecordSet.Filter["ObjectWithIssue"].Set(Selection["ObjectWithIssue"]);
		RecordSet.Filter["IssueType"].Set(Selection["IssueType"]);
		
		FillPropertyValues(RecordSet.Add(), Selection);
		
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf