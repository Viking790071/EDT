#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", 					DocumentRef);
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.PaymentMethod AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	CASE
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN DocumentTable.PettyCash
	|		WHEN DocumentTable.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN DocumentTable.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	&Ref AS Quote,
	|	DocumentTable.DocumentCurrency AS Currency,
	|	DocumentTable.DocumentAmount AS Amount,
	|	DocumentTable.CashAssetType AS CashAssetType
	|FROM
	|	Document.CashInflowForecast AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Creates a document data table.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document StructureAdditionalProperties - AdditionalProperties - Additional properties of the document
//	
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndIf