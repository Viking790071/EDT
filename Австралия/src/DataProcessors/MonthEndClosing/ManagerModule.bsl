#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure ExecuteMonthEnd(ParametersStructure, BackgroundJobStorageAddress = "") Export
	
	CurMonth = ParametersStructure.CurMonth;
	CurYear = ParametersStructure.CurYear;
	Company = ParametersStructure.Company;
	OperationArray = ParametersStructure.OperationArray;
	
	StructureOfCurrentDocuments = CancelMonthEnd(ParametersStructure);
	
	If ParametersStructure.ExecuteCalculationOfDepreciation Then
		
		If ValueIsFilled(StructureOfCurrentDocuments.DocumentFixedAssetsDepreciation) Then
			
			DocObject = StructureOfCurrentDocuments.DocumentFixedAssetsDepreciation.GetObject();
			If DocObject.DeletionMark Then
				DocObject.SetDeletionMark(False);
			EndIf;
			
		Else
			
			DocObject = Documents.FixedAssetsDepreciation.CreateDocument();
			
			SetAttributesOfObjectDocument(DocObject, Company, CurYear, CurMonth);
			
		EndIf;
		
		DocObject.Write(DocumentWriteMode.Posting);
		
	EndIf;
	
	RunOperationClosingMonth(ParametersStructure, OperationArray, StructureOfCurrentDocuments.DocumentMonthEnd);
	
EndProcedure

Function CancelMonthEnd(ParametersStructure) Export
	
	CurMonth = ParametersStructure.CurMonth;
	CurYear = ParametersStructure.CurYear;
	Company = ParametersStructure.Company;
	
	ReturnStructure = New Structure("DocumentMonthEnd, DocumentFixedAssetsDepreciation");
	
	Query = New Query;
	
	Query.Text =
	"SELECT ALLOWED
	|	MonthEndClosing.Date AS Date,
	|	MonthEndClosing.Ref AS Ref
	|FROM
	|	Document.MonthEndClosing AS MonthEndClosing
	|WHERE
	|	YEAR(MonthEndClosing.Date) = &Year
	|	AND MONTH(MonthEndClosing.Date) = &Month
	|	AND MonthEndClosing.Company = &Company
	|
	|ORDER BY
	|	Date,
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	FixedAssetsDepreciation.Date AS Date,
	|	FixedAssetsDepreciation.Ref AS Ref
	|FROM
	|	Document.FixedAssetsDepreciation AS FixedAssetsDepreciation
	|WHERE
	|	YEAR(FixedAssetsDepreciation.Date) = &Year
	|	AND MONTH(FixedAssetsDepreciation.Date) = &Month
	|	AND FixedAssetsDepreciation.Company = &Company
	|
	|ORDER BY
	|	Date,
	|	Ref";
	
	Query.SetParameter("Year", CurYear);
	Query.SetParameter("Month", CurMonth);
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.ExecuteBatch();
	
	DocSelection = QueryResult[1].Select();
	While DocSelection.Next() Do
		
		DocObject = DocSelection.Ref.GetObject();
		If DocObject.DeletionMark Then
			DocObject.SetDeletionMark(False);
		EndIf;
		
		DocObject.Write(DocumentWriteMode.UndoPosting);
		ReturnStructure.DocumentFixedAssetsDepreciation = DocSelection.Ref;
		
	EndDo;
	
	ReturnStructure.DocumentMonthEnd = Undefined;
	
	DocSelection = QueryResult[0].Select();
	While DocSelection.Next() Do
		
		DocObject = DocSelection.Ref.GetObject();
		If DocObject.DeletionMark Then
			DocObject.SetDeletionMark(False);
		EndIf;
		
		DocObject.Write(DocumentWriteMode.UndoPosting);
		
		If ReturnStructure.DocumentMonthEnd = Undefined Then
			ReturnStructure.DocumentMonthEnd = DocSelection.Ref;
		EndIf;
		
	EndDo;
	
	Return ReturnStructure;
	
EndFunction

#EndRegion

#Region Private

#Region ServiceProceduresAndFunctions

Procedure RunOperationClosingMonth(ParametersStructure, Operations, DocumentClosingMonth)
	
	CurMonth = ParametersStructure.CurMonth;
	CurYear = ParametersStructure.CurYear;
	Company = ParametersStructure.Company;
	
	If DocumentClosingMonth = Undefined Then
		
		DocObject = Documents.MonthEndClosing.CreateDocument();
		
		SetAttributesOfObjectDocument(DocObject, Company, CurYear, CurMonth);
		
	Else
		
		DocObject = DocumentClosingMonth.GetObject();
		
		If DocObject.DeletionMark Then
			DocObject.SetDeletionMark(False);
		EndIf;
		
		DocObject.DirectCostCalculation = False;
		DocObject.CostAllocation = False;
		DocObject.ActualCostCalculation = False;
		DocObject.FinancialResultCalculation = False;
		DocObject.ExchangeDifferencesCalculation = False;
		DocObject.RetailCostCalculationEarningAccounting = False;
		DocObject.VerifyTaxInvoices = False;
		DocObject.VATPayableCalculation = False;
		
	EndIf;
	
	For Each Operation In Operations Do
		DocObject[Operation] = True;
	EndDo;
	
	DocObject.Write(DocumentWriteMode.Posting);
	
EndProcedure

#EndRegion

Procedure SetAttributesOfObjectDocument(ObjectDocument, Company, CurYear, CurMonth)
	
	ObjectDocument.Company	= Company;
	ObjectDocument.Date		= EndOfMonth(Date(CurYear, CurMonth, 1));
	ObjectDocument.Author	= Users.AuthorizedUser();
	ObjectDocument.Comment	= NStr("en = '#Created automatically using month-end closing wizard.'; ru = '#Создан автоматически помощником закрытия месяца.';pl = '#Utworzony automatycznie przy użyciu kreatora zamknięcia końca miesiąca.';es_ES = '#Creado automáticamente utilizando el asistente de cierre del fin de mes.';es_CO = '#Creado automáticamente utilizando el asistente de cierre del fin de mes.';tr = '#Ay sonu kapanış sihirbazı kullanılarak otomatik olarak oluşturuldu.';it = '#Creato automaticamente, con l''assistente guidato di chiusura di fine periodo.';de = '# Wird automatisch mit dem Monatsabschluss-Assistenten erstellt.'");
	
EndProcedure

#EndRegion

#EndIf