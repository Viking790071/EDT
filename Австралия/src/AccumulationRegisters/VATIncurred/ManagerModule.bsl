#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure creates an empty temporary table of records change.
//
Procedure CreateEmptyTemporaryTableChange(AdditionalProperties) Export
	
	If Not AdditionalProperties.Property("ForPosting")
		OR Not AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	Query = New Query(
	"SELECT TOP 0
	|	VATIncurred.LineNumber AS LineNumber,
	|	VATIncurred.Company AS Company,
	|	VATIncurred.PresentationCurrency AS PresentationCurrency,
	|	VATIncurred.Supplier AS Supplier,
	|	VATIncurred.ShipmentDocument AS ShipmentDocument,
	|	VATIncurred.VATRate AS VATRate,
	|	VATIncurred.AmountExcludesVAT AS AmountExcludesVATBeforeWrite,
	|	VATIncurred.AmountExcludesVAT AS AmountExcludesVATChange,
	|	VATIncurred.AmountExcludesVAT AS AmountExcludesVATOnWrite,
	|	VATIncurred.VATAmount AS VATAmountBeforeWrite,
	|	VATIncurred.VATAmount AS VATAmountChange,
	|	VATIncurred.VATAmount AS VATAmountOnWrite
	|INTO RegisterRecordsVATIncurredChange
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred");
	
	Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureTemporaryTables.Insert("RegisterRecordsVATIncurredChange", False);
	
EndProcedure

Function BalancesControlQueryText() Export
	
	Return
	"SELECT ALLOWED
	|	RegisterRecordsVATIncurredChange.LineNumber AS LineNumber,
	|	RegisterRecordsVATIncurredChange.Company AS Company,
	|	RegisterRecordsVATIncurredChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsVATIncurredChange.Supplier AS Supplier,
	|	RegisterRecordsVATIncurredChange.ShipmentDocument AS ShipmentDocument,
	|	RegisterRecordsVATIncurredChange.VATRate AS VATRate,
	|	RegisterRecordsVATIncurredChange.AmountExcludesVATOnWrite AS AmountExcludesVAT,
	|	ISNULL(VATIncurredBalances.AmountExcludesVATBalance, 0) AS AmountExcludesVATBalance,
	|	RegisterRecordsVATIncurredChange.VATAmountOnWrite AS VATAmount,
	|	ISNULL(VATIncurredBalances.VATAmountBalance, 0) AS VATAmountBalance
	|INTO TT_RegisterRecordsVATIncurredChange
	|FROM
	|	RegisterRecordsVATIncurredChange AS RegisterRecordsVATIncurredChange
	|		LEFT JOIN AccumulationRegister.VATIncurred.Balance(&ControlTime, ) AS VATIncurredBalances
	|		ON RegisterRecordsVATIncurredChange.Company = VATIncurredBalances.Company
	|			AND RegisterRecordsVATIncurredChange.PresentationCurrency = VATIncurredBalances.PresentationCurrency
	|			AND RegisterRecordsVATIncurredChange.Supplier = VATIncurredBalances.Supplier
	|			AND RegisterRecordsVATIncurredChange.ShipmentDocument = VATIncurredBalances.ShipmentDocument
	|			AND RegisterRecordsVATIncurredChange.VATRate = VATIncurredBalances.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RegisterRecordsVATIncurredChange.LineNumber AS LineNumber,
	|	RegisterRecordsVATIncurredChange.Company AS Company,
	|	RegisterRecordsVATIncurredChange.PresentationCurrency AS PresentationCurrency,
	|	RegisterRecordsVATIncurredChange.Supplier AS Supplier,
	|	RegisterRecordsVATIncurredChange.ShipmentDocument AS ShipmentDocument,
	|	RegisterRecordsVATIncurredChange.VATRate AS VATRate,
	|	RegisterRecordsVATIncurredChange.AmountExcludesVAT AS AmountExcludesVAT,
	|	RegisterRecordsVATIncurredChange.AmountExcludesVATBalance AS AmountExcludesVATBalance,
	|	RegisterRecordsVATIncurredChange.VATAmount AS VATAmount,
	|	RegisterRecordsVATIncurredChange.VATAmountBalance AS VATAmountBalance
	|FROM
	|	TT_RegisterRecordsVATIncurredChange AS RegisterRecordsVATIncurredChange
	|WHERE
	|	NOT RegisterRecordsVATIncurredChange.ShipmentDocument REFS Document.DebitNote
	|	AND (RegisterRecordsVATIncurredChange.AmountExcludesVATBalance < 0
	|			OR RegisterRecordsVATIncurredChange.VATAmountBalance < 0)
	|
	|UNION ALL
	|
	|SELECT
	|	RegisterRecordsVATIncurredChange.LineNumber,
	|	RegisterRecordsVATIncurredChange.Company,
	|	RegisterRecordsVATIncurredChange.PresentationCurrency,
	|	RegisterRecordsVATIncurredChange.Supplier,
	|	RegisterRecordsVATIncurredChange.ShipmentDocument,
	|	RegisterRecordsVATIncurredChange.VATRate,
	|	RegisterRecordsVATIncurredChange.AmountExcludesVAT,
	|	-RegisterRecordsVATIncurredChange.AmountExcludesVATBalance,
	|	RegisterRecordsVATIncurredChange.VATAmount,
	|	-RegisterRecordsVATIncurredChange.VATAmountBalance
	|FROM
	|	TT_RegisterRecordsVATIncurredChange AS RegisterRecordsVATIncurredChange
	|WHERE
	|	RegisterRecordsVATIncurredChange.ShipmentDocument REFS Document.DebitNote
	|	AND (RegisterRecordsVATIncurredChange.AmountExcludesVATBalance > 0
	|			OR RegisterRecordsVATIncurredChange.VATAmountBalance > 0)
	|
	|ORDER BY
	|	LineNumber";
	
EndFunction

#EndRegion

#EndIf