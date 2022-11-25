#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]						= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SalesOrder")]			= "FillBySalesOrder";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, Mode)

	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.PackingSlip.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectPackedOrders(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();

EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
EndProcedure

#EndRegion

#Region Private

#Region DocumentFillingProcedures

Procedure FillBySalesOrder(FillingData) Export
	
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSalesOrders") Then
		OrdersArray = FillingData.ArrayOfSalesOrders;
	Else
		OrdersArray.Add(FillingData.Ref);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnit,
	|	SalesOrder.Posted AS Posted,
	|	SalesOrder.Closed AS Closed,
	|	SalesOrder.OrderState AS OrderState,
	|	SalesOrder.Ref AS Ref
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		FillPropertyValues(ThisObject, Selection);
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted",
			Selection.OrderState,
			Selection.Closed,
			Selection.Posted);
		Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(Selection.Ref, VerifiedAttributesValues);
		
		RowOrder = SalesOrders.Add();
		RowOrder.SalesOrder = Selection.Ref;
		
	EndDo;
		
EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfSalesOrders") Then
		FillBySalesOrder(FillingData);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf