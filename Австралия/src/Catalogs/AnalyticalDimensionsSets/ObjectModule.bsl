
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DistinctAnalyticalDimensions = New ValueList;
	For Each Row In AnalyticalDimensions Do
		
		If DistinctAnalyticalDimensions.FindByValue(Row.AnalyticalDimension) = Undefined Then
			
			DistinctAnalyticalDimensions.Add(Row.AnalyticalDimension);
			
		Else
			
			DriveServer.ShowMessageAboutError(ThisObject,
				MessagesToUserClientServer.GetRestrictedDuplicatesErrorText(),
				"AnalyticalDimensions",
				Row.LineNumber,
				"AnalyticalDimension",
				Cancel);
			
		EndIf;
		
	EndDo;
	
	If Not Cancel
		And ValueIsFilled(Ref) 
		And CheckDifferenceInAnalyticalDimensions() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	MasterChartOfAccounts.Ref AS Ref,
		|	""Account"" AS TS,
		|	"""" AS DrCr,
		|	0 AS LineNumber
		|INTO TT_TotalTable
		|FROM
		|	ChartOfAccounts.MasterChartOfAccounts AS MasterChartOfAccounts
		|WHERE
		|	MasterChartOfAccounts.AnalyticalDimensionsSet = &AnalyticalDimensionsSet
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	AccountingEntriesTemplatesEntries.Ref,
		|	""Entries"",
		|	"""",
		|	AccountingEntriesTemplatesEntries.LineNumber
		|FROM
		|	Catalog.AccountingEntriesTemplates.Entries AS AccountingEntriesTemplatesEntries
		|WHERE
		|	AccountingEntriesTemplatesEntries.AnalyticalDimensionsSet = &AnalyticalDimensionsSet
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	AccountingEntriesTemplatesEntriesSimple.Ref,
		|	""EntriesSimple"",
		|	""Dr"",
		|	AccountingEntriesTemplatesEntriesSimple.LineNumber
		|FROM
		|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
		|WHERE
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsSetDr = &AnalyticalDimensionsSet
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	AccountingEntriesTemplatesEntriesSimple.Ref,
		|	""EntriesSimple"",
		|	""Cr"",
		|	AccountingEntriesTemplatesEntriesSimple.LineNumber
		|FROM
		|	Catalog.AccountingEntriesTemplates.EntriesSimple AS AccountingEntriesTemplatesEntriesSimple
		|WHERE
		|	AccountingEntriesTemplatesEntriesSimple.AnalyticalDimensionsSetCr = &AnalyticalDimensionsSet
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	TT_TotalTable.Ref AS Ref,
		|	TT_TotalTable.TS AS TS,
		|	TT_TotalTable.DrCr AS DrCr,
		|	TT_TotalTable.LineNumber AS LineNumber
		|FROM
		|	TT_TotalTable AS TT_TotalTable";
		
		Query.SetParameter("AnalyticalDimensionsSet", Ref);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		ErrorMessageTemplateAccount = NStr("en = 'Unable to edit Analytical dimensions. This Analytical dimension set is used in account %1'; ru = '???? ?????????????? ???????????????? ?????????????????????????? ??????????????????. ???????? ?????????? ?????????????????????????? ?????????????????? ???????????????????????? ?? ?????????? %1';pl = 'Nie mo??na edytowa?? wymiar??w analitycznych. Ten wymiar analityczny jest u??ywany na koncie %1';es_ES = 'No se pueden editar las dimensiones anal??ticas. Este conjunto de dimensiones anal??ticas se utiliza en la cuenta %1';es_CO = 'No se pueden editar las dimensiones anal??ticas. Este conjunto de dimensiones anal??ticas se utiliza en la cuenta %1';tr = 'Analitik boyutlar d??zenlenemiyor. Bu Analitik boyut k??mesi, %1 hesab??nda kullan??l??yor';it = 'Impossibile modificare le dimensioni analitiche. Questo set di dimensioni analitiche ?? utilizzato nel conto %1';de = 'Fehler beim Bearbeiten von Analytischen Messungen. Dieser Satz von analytischen Messungen ist im Konto %1 verwendet'");
		ErrorMessageTemplateCatalog = NStr("en = 'Unable to edit Analytical dimensions. This Analytical dimension set is used in accounting entries templates %1, line %2'; ru = '???? ?????????????? ???????????????? ?????????????????????????? ??????????????????. ???????? ?????????? ?????????????????????????? ?????????????????? ???????????????????????? ?? ???????????? %2 ?????????????? ?????????????????????????? ???????????????? %1';pl = 'Nie mo??na edytowa?? wymiar??w analitycznych. Ten wymiar analityczny jest u??ywany w szablonach wpis??w ksi??gowych %1, wiersz %2';es_ES = 'No se pueden editar las dimensiones anal??ticas. Este conjunto de dimensiones anal??ticas se utiliza en las plantillas de entradas contables%1 l??nea%2 ';es_CO = 'No se pueden editar las dimensiones anal??ticas. Este conjunto de dimensiones anal??ticas se utiliza en las plantillas de entradas contables%1 l??nea%2 ';tr = 'Analitik boyutlar d??zenlenemiyor. Bu Analitik boyut k??mesi %1 muhasebe giri??i ??ablonlar??n??n %2 sat??r??nda kullan??l??yor';it = 'Impossibile modificare le dimensioni analitiche. Questo set di dimensioni analitiche ?? utilizzato nei modelli di voci di contabilit?? %1, riga %2';de = 'Fehler beim Bearbeiten von Analytischen Messungen. Dieser Satz von analytischen Messungen ist in Buchungsvorlagen %1, Zeile %2 verwendet'");
		While SelectionDetailRecords.Next() Do
			
			Field		 = "";
			ErrorMessage = "";
			If SelectionDetailRecords.TS = "Account" Then
				
				ErrorMessage = StrTemplate(ErrorMessageTemplateAccount, SelectionDetailRecords.Ref);
				Field = "AnalyticalDimensionsSet";
				
			Else
				
				ErrorMessage = StrTemplate(ErrorMessageTemplateCatalog, SelectionDetailRecords.Ref, SelectionDetailRecords.LineNumber);
				Field = CommonClientServer.PathToTabularSection(
					SelectionDetailRecords.TS, 
					SelectionDetailRecords.LineNumber, 
					"AnalyticalDimensionsSet" + SelectionDetailRecords.DrCr);
				
			EndIf;
			
			CommonClientServer.MessageToUser(ErrorMessage, SelectionDetailRecords.Ref, Field, "Object", Cancel);
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function CheckDifferenceInAnalyticalDimensions()
	
	For Each Row In Ref.AnalyticalDimensions Do
		
		Rows = AnalyticalDimensions.FindRows(New Structure("AnalyticalDimension", Row.AnalyticalDimension));
		If Rows.Count() = 0 Then
			Return True;
		EndIf;
		
	EndDo;
	
	For Each Row In AnalyticalDimensions Do
		
		Rows = Ref.AnalyticalDimensions.FindRows(New Structure("AnalyticalDimension", Row.AnalyticalDimension));
		If Rows.Count() = 0 Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion

#EndIf