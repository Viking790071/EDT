#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Private

#Region EventHandlers

Procedure Filling(FillingData, StandardProcessing)
	
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.RequisitionOrder")]	= "FillByRequisitionOrder";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillByRequisitionOrder(DocumentRefRequisitionOrder) Export
	
	Query = New Query(
	"SELECT ALLOWED
	|	RequisitionOrder.Ref AS Order,
	|	RequisitionOrder.Company AS Company,
	|	RequisitionOrder.Inventory.(
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity
	|	) AS Products,
	|	RequisitionOrder.ReceiptDate AS ClosingDate
	|FROM
	|	Document.RequisitionOrder AS RequisitionOrder
	|WHERE
	|	RequisitionOrder.Ref = &BasisDocument");
	
	Query.SetParameter("BasisDocument", DocumentRefRequisitionOrder);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	FillPropertyValues(ThisObject, QueryResultSelection);
	
	Products.Load(QueryResultSelection.Products.Unload());
		
EndProcedure

#EndRegion

#EndRegion

#EndIf