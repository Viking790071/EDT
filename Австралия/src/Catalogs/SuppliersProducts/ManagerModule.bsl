#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function CounterpartyUsesProductCrossReferences(Counterparty) Export 
	
	IsUseProductCrossReferences = Constants.UseProductCrossReferences.Get();
	
	If Not IsUseProductCrossReferences Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	SuppliersProducts.Ref AS Ref
	|FROM
	|	Catalog.SuppliersProducts AS SuppliersProducts
	|WHERE
	|	SuppliersProducts.Owner = &Counterparty";
	
	Query.SetParameter("Counterparty", Counterparty);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Procedure FindCrossReferenceByParameters(StructureData) Export 
	
	StructureData.Insert("CrossReference", Catalogs.SuppliersProducts.EmptyRef());
	
	If Not StructureData.Property("Characteristic") Then
		StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
	EndIf;
	
	StructureDefaultCrossReference = Common.ObjectAttributesValues(StructureData.Products, "ProductCrossReference, Vendor");
	
	DefaultCrossReference = StructureDefaultCrossReference.ProductCrossReference;
	
	If ValueIsFilled(DefaultCrossReference)
		And (Not StructureData.Property("Counterparty")
			Or StructureData.Counterparty = StructureDefaultCrossReference.Vendor) Then
		
		StructureData.Insert("CrossReference", DefaultCrossReference);
		
	ElsIf StructureData.Property("Counterparty") Then
			
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	SuppliersProducts.Ref AS Ref
		|FROM
		|	Catalog.SuppliersProducts AS SuppliersProducts
		|WHERE
		|	SuppliersProducts.Owner = &Counterparty
		|	AND SuppliersProducts.Products = &Products
		|	AND SuppliersProducts.Characteristic = &Characteristic
		|	AND NOT SuppliersProducts.DeletionMark";
		
		Query.SetParameter("Counterparty", StructureData.Counterparty);
		Query.SetParameter("Products", StructureData.Products);
		Query.SetParameter("Characteristic", StructureData.Characteristic);
		
		SuppliersProducts = Query.Execute().Unload();
		If SuppliersProducts.Count() = 1 Then
			StructureData.Insert("CrossReference", SuppliersProducts[0].Ref);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region CloneProductRelatedData

Procedure MakeRelatedProductCrossreferences(ProductReceiver, ProductSource) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	SuppliersProducts.Ref AS SupplierProduct,
		|	SuppliersProducts.Products AS Products
		|FROM
		|	Catalog.SuppliersProducts AS SuppliersProducts
		|WHERE
		|	SuppliersProducts.Products = &ProductSource";
	
	Query.SetParameter("ProductSource", ProductSource);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		SupplierProductReceiver = SelectionDetailRecords.SupplierProduct.Copy();
		SupplierProductReceiver.Products = ProductReceiver;
		SupplierProductReceiver.Write();
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.SuppliersProducts);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	
	Fields.Add("SKU");
	Fields.Add("Description");
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	StandardProcessing = False;
	Presentation = Data.SKU + " " + Data.Description;
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

#EndRegion

#Region Internal

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	AttributesToLock.Add("Products");
	AttributesToLock.Add("Characteristic");
	AttributesToLock.Add("SKU");
	AttributesToLock.Add("Owner");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndIf