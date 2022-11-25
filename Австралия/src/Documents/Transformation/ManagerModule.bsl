#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefTransformation, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefTransformation);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	Transformation.Date AS Date,
	|	&Company AS Company,
	|	Transformation.PostingDateFromDocument AS PostingDateFromDocument,
	|	Transformation.Ref AS Ref
	|INTO TransformationTable
	|FROM
	|	Document.Transformation AS Transformation
	|WHERE
	|	Transformation.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN TransformationTable.PostingDateFromDocument
	|			THEN TransformationTable.Date
	|		ELSE TransformationPostings.PostingDate
	|	END AS Period,
	|	TransformationTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TransformationPostings.Debit AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	TransformationPostings.Credit AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	TransformationPostings.Amount AS Amount,
	|	TransformationPostings.Content AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.Transformation.Postings AS TransformationPostings
	|		INNER JOIN TransformationTable AS TransformationTable
	|		ON TransformationPostings.Ref = TransformationTable.Ref";
	
	QueryResult = Query.Execute();
	
	AccountingRegister = Common.ObjectAttributeValue(DocumentRefTransformation, "AccountingRegister");
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableJournalEntries", QueryResult.Unload());
	StructureAdditionalProperties.ForPosting.Insert("AccountingRegisterName", AccountingRegister.Name);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefTransformation, StructureAdditionalProperties);
	
EndProcedure

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndIf
