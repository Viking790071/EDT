#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.Products);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region ProgramInterface

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("ProductsType");
	Result.Add("IsFreightService");
	
	Return Result;
	
EndFunction

// Returns the list of
// attributes allowed to be changed with the help of the group change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	
	EditableAttributes.Add("ProductsType");
	EditableAttributes.Add("VATRate");
	EditableAttributes.Add("BusinessLine");
	EditableAttributes.Add("Warehouse");
	EditableAttributes.Add("Cell");
	EditableAttributes.Add("ProductsCategory");
	EditableAttributes.Add("PriceGroup");
	EditableAttributes.Add("CountryOfOrigin");
	EditableAttributes.Add("ReplenishmentMethod");
	EditableAttributes.Add("ReplenishmentDeadline");
	EditableAttributes.Add("Vendor");

	
	Return EditableAttributes;
	
EndFunction

// Returns the basic sale price for the specified items by the specified price type.
//
// Products (Catalog.Products) - products which price shall be calculated (obligatory for filling);
// PriceKind (Catalog.PriceTypes or Undefined) - If Undefined, we calculate the basic price type using
// Catalogs.PriceTypes.GetBasicSalePriceKind() method;
//
Function GetMainSalePrice(PriceKind, Products, MeasurementUnit = Undefined) Export
	
	If Not ValueIsFilled(Products) 
		OR Not AccessRight("Read", Metadata.InformationRegisters.Prices) Then
		
		Return 0;
		
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	PricesSliceLast.Price AS MainSalePrice
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			,
	|			PriceKind = &PriceKind
	|				AND Products = &Products
	|				AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|				AND &ParameterMeasurementUnit) AS PricesSliceLast");
	
	Query.SetParameter("PriceKind", 
		?(ValueIsFilled(PriceKind), PriceKind, Catalogs.PriceTypes.GetMainKindOfSalePrices())
		);
	
	Query.SetParameter("Products", 
		Products
		);
		
	If ValueIsFilled(MeasurementUnit) Then
		
		Query.Text = StrReplace(Query.Text, "&ParameterMeasurementUnit", "MeasurementUnit = &MeasurementUnit");
		Query.SetParameter("MeasurementUnit", MeasurementUnit);
		
	Else
		
		Query.Text = StrReplace(Query.Text, "&ParameterMeasurementUnit", "TRUE");
		
	EndIf;
	
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.MainSalePrice, 0);
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ProductCardForExternalUsers") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"ProductCardForExternalUsers", 
			NStr("en = 'Product card'; ru = 'Карточка номенклатуры';pl = 'Karta produktu';es_ES = 'Tarjeta del producto';es_CO = 'Tarjeta del producto';tr = 'Ürün kartı';it = 'Scheda articolo';de = 'Produktkarte'"),
			PrintForm(ObjectsArray, PrintObjects, "ProductCardForExternalUsers", PrintParameters));
		
	EndIf;
	
EndProcedure

// Function checks if the document is posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	// MultilingualSupport
	LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();

	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	// End MultilingualSupport
	
	Company = Undefined;
	If PrintParams <> Undefined And PrintParams.Property("Company") Then
		Company = PrintParams.Company;
	EndIf;
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_Products";
	
	FirstProduct = True;
	
	For Each CurrentProduct In ObjectsArray Do
	
		If Not FirstProduct Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstProduct = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "ProductCardForExternalUsers" Then
			
			Query = New Query;
			Query.Text = "SELECT ALLOWED
			|	Products.SKU AS SKU,
			|	Products.Description AS Description,
			|	Products.DescriptionFull AS DescriptionFull,
			|	Products.GuaranteePeriod AS WarrantyPeriod,
			|	Products.Manufacturer AS Manufacturer,
			|	Products.MeasurementUnit AS Units,
			|	Products.PictureFile AS PictureFile,
			|	Products.Weight AS Weight,
			|	Products.AccessGroup AS Group,
			|	Products.UseCharacteristics AS UseCharacteristics
			|FROM
			|	Catalog.Products AS Products
			|WHERE
			|	Products.Ref = &Ref
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	AdditionalAttributesAndInfo.Title AS Property,
			|	ProductsAdditionalAttributes.Value AS Value
			|FROM
			|	Catalog.Products.AdditionalAttributes AS ProductsAdditionalAttributes
			|		LEFT JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
			|		ON ProductsAdditionalAttributes.Property = AdditionalAttributesAndInfo.Ref
			|WHERE
			|	ProductsAdditionalAttributes.Ref = &Ref
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	ProductsCharacteristics.Ref AS Ref
			|FROM
			|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
			|WHERE
			|	ProductsCharacteristics.Owner = &Ref
			|	AND NOT ProductsCharacteristics.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	InventoryInWarehousesOfBalance.StructuralUnit AS StructuralUnit,
			|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) - ISNULL(ReservedProductsBalances.QuantityBalance, 0) AS Available,
			|	InventoryInWarehousesOfBalance.Characteristic AS Characteristic
			|INTO TT_Available
			|FROM
			|	AccumulationRegister.InventoryInWarehouses.Balance(
			|			,
			|			Company = &Company
			|				AND Products = &Ref) AS InventoryInWarehousesOfBalance
			|		LEFT JOIN AccumulationRegister.ReservedProducts.Balance(
			|				,
			|				Company = &Company
			|					AND Products = &Ref
			|					AND StructuralUnit REFS Catalog.BusinessUnits
			|					AND SalesOrder <> UNDEFINED) AS ReservedProductsBalances
			|		ON InventoryInWarehousesOfBalance.StructuralUnit = ReservedProductsBalances.StructuralUnit
			|			AND InventoryInWarehousesOfBalance.Products = ReservedProductsBalances.Products
			|			AND InventoryInWarehousesOfBalance.Characteristic = ReservedProductsBalances.Characteristic
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TT_Available.StructuralUnit AS StructuralUnit,
			|	SUM(TT_Available.Available) AS Available
			|FROM
			|	TT_Available AS TT_Available
			|
			|GROUP BY
			|	TT_Available.StructuralUnit
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	TT_Available.StructuralUnit AS StructuralUnit,
			|	TT_Available.Available AS Available,
			|	TT_Available.Characteristic AS Characteristic
			|FROM
			|	TT_Available AS TT_Available
			|WHERE
			|	TT_Available.Characteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)";
			
			Query.SetParameter("Ref", CurrentProduct);
			Query.SetParameter("Company", Company);
			
			// MultilingualSupport
			DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
			// End MultilingualSupport
			
			QueryResults = Query.ExecuteBatch();
			
			MainSelection = QueryResults[0].Select();
			MainSelection.Next();
			
			SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_Products_ProductCardForExternalUsers";
			
			Template = PrintManagement.PrintFormTemplate("Catalog.Products.ProductCardForExternalUsers", LanguageCode);
			
			TemplateArea = Template.GetArea("MainArea");
			FillPropertyValues(TemplateArea.Parameters, MainSelection);
			
			SpreadsheetDocument.Put(TemplateArea);
			
			Units = MainSelection.Units;
			
			If GetFunctionalOption("UseAdditionalAttributesAndInfo") And Not QueryResults[1].IsEmpty() Then
				PropertiesHead = Template.GetArea("PropertiesHead");
				SpreadsheetDocument.Put(PropertiesHead);
				
				PropertiesLine = Template.GetArea("PropertiesLine");
				
				PropertiesSelection = QueryResults[1].Select();
				While PropertiesSelection.Next() Do
					FillPropertyValues(PropertiesLine.Parameters, PropertiesSelection);
					SpreadsheetDocument.Put(PropertiesLine);
				EndDo;
				
				PropertiesBorder = Template.GetArea("PropertiesBorder");
				SpreadsheetDocument.Put(PropertiesBorder);
			EndIf;
			
			JoinSpreadsheetDocument = New SpreadsheetDocument;
			JoinArea = Template.GetArea("JoinArea | JoinItem");
			
			If ValueIsFilled(MainSelection.PictureFile) Then
				
				PictureData = AttachedFiles.GetBinaryFileData(MainSelection.PictureFile);
				If ValueIsFilled(PictureData) Then
					JoinArea.Drawings.ProductPicture.Picture = New Picture(PictureData);
				EndIf;
				
			Else
				
				JoinArea.Drawings.Delete(JoinArea.Drawings.ProductPicture);
				
			EndIf;
			
			JoinSpreadsheetDocument.Put(JoinArea);
			
			JoinWarehouse = Template.GetArea("JoinArea | JoinWarehouse");
			
			If QueryResults[4].IsEmpty() Then
				
				JoinWarehouse.Parameters.Available = 0;
				JoinWarehouse.Parameters.Units = Units;
				JoinSpreadsheetDocument.Join(JoinWarehouse);
				JoinSpreadsheetDocument.Put(Template.GetArea("JoinBorder"));
				
			Else
				
				StructuralUnitSelection = QueryResults[4].Select();
				While StructuralUnitSelection.Next() Do
					FillPropertyValues(JoinWarehouse.Parameters, StructuralUnitSelection);
					JoinWarehouse.Parameters.Units = Units;
					JoinSpreadsheetDocument.Join(JoinWarehouse);
				EndDo;
				
				UseCharacteristics = GetFunctionalOption("UseCharacteristics")
					And MainSelection.UseCharacteristics
					And Not QueryResults[2].IsEmpty();
				
				If UseCharacteristics Then
					CharacteristicsTable = QueryResults[5].Unload();
					
					Characteristics = CharacteristicsTable.Copy(,"Characteristic");
					Characteristics.GroupBy("Characteristic");
					CharacteristicsArray = Characteristics.UnloadColumn("Characteristic");
					
					JoinCharacteristicsLine = Template.GetArea("JoinCharacteristicsLine | JoinItem");
					
					For Each Characteristic In CharacteristicsArray Do
						JoinCharacteristicsLine.Parameters.Characteristic = Characteristic;
						JoinSpreadsheetDocument.Put(JoinCharacteristicsLine);
						
						StructuralUnitSelection.Reset();
						While StructuralUnitSelection.Next() Do
							JoinCharacteristicsLineAvailable = Template.GetArea("JoinCharacteristicsLine | JoinWarehouse");
							
							Filter = New Structure;
							Filter.Insert("Characteristic", Characteristic);
							Filter.Insert("StructuralUnit", StructuralUnitSelection.StructuralUnit);
							CharacteristicRows = CharacteristicsTable.FindRows(Filter);
							If CharacteristicRows.Count() Then
								FillPropertyValues(JoinCharacteristicsLineAvailable.Parameters, CharacteristicRows[0]);
								JoinCharacteristicsLineAvailable.Parameters.Units = Units;
							EndIf;
							JoinSpreadsheetDocument.Join(JoinCharacteristicsLineAvailable);
						EndDo;
					EndDo;
				EndIf;
				
				JoinSpreadsheetDocument.Put(Template.GetArea("JoinBorder | JoinItem"));
				
				StructuralUnitSelection.Reset();
				While StructuralUnitSelection.Next() Do
					JoinSpreadsheetDocument.Join(Template.GetArea("JoinBorder | JoinWarehouse"));
				EndDo;
				
			EndIf;
			
			FullSpreadsheetDocument = New SpreadsheetDocument;
			FullSpreadsheetDocument.Put(SpreadsheetDocument.GetArea(1,1,SpreadsheetDocument.TableHeight,SpreadsheetDocument.TableWidth));
			FullSpreadsheetDocument.Join(JoinSpreadsheetDocument.GetArea(1,1,JoinSpreadsheetDocument.TableHeight,JoinSpreadsheetDocument.TableWidth));
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(FullSpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentProduct);
		
	EndDo;
	
	FullSpreadsheetDocument.FitToPage = True;
	
	Return FullSpreadsheetDocument;
	
EndFunction

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region ObjectAttributesLock

// StandardSubsystems.ObjectAttributesLock

// See ObjectsAttributesEditBlockedOverridable.OnDefineObjectsWithLockedAttributes. 
Function GetObjectAttributesToLock() Export
	
	AttributesToLock = New Array;
	
	AttributesToLock.Add("DescriptionFull");
	AttributesToLock.Add("ProductsType");
	AttributesToLock.Add("IsFreightService");
	AttributesToLock.Add("MeasurementUnit");
	AttributesToLock.Add("GuaranteePeriod");
	AttributesToLock.Add("WriteOutTheGuaranteeCard");
	AttributesToLock.Add("UseCharacteristics");
	AttributesToLock.Add("UseBatches");
	AttributesToLock.Add("UseSerialNumbers");
	AttributesToLock.Add("ProductsCategory");
	AttributesToLock.Add("PriceGroup");
	AttributesToLock.Add("IsBundle");
	AttributesToLock.Add("BundlePricingStrategy");
	AttributesToLock.Add("BundleDisplayInPrintForms");
	AttributesToLock.Add("Taxable");
	
	Return AttributesToLock;
	
EndFunction

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

#EndRegion

#EndIf