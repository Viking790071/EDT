
#Region Public

Procedure AddBundleComponent(BundleProduct, BundleCharacteristic, TableName, OldCount, Val NewCount = Undefined, Variant = Undefined, BundleAttributes = Undefined) Export
	
	If BundleAttributes = Undefined Then
		BundleAttributes = BundlesServerCall.BundleAttributes(BundleProduct, BundleCharacteristic);
	Else
		CollapseBundle(BundleProduct, BundleCharacteristic, BundleAttributes.BundlesComponents, Variant);
	EndIf;
	
	RecalculatePrices = TableName.Count() > 0
		And TableName[0].Property("Price")
		And BundleAttributes.BundlePricingStrategy <> PredefinedValue("Enum.ProductBundlePricingStrategy.PerComponentPricing")
		And BundleAttributes.BundlePricingStrategy <> PredefinedValue("Enum.ProductBundlePricingStrategy.EmptyRef");
	
	If RecalculatePrices Then
		BundlePrice = 0;
		BundleRows = BundleRows(BundleProduct, BundleCharacteristic, TableName, Variant);
		For Each TableRow In BundleRows Do
			BundlePrice = BundlePrice + TableRow.Price * TableRow.Quantity;
		EndDo;
	EndIf;
	
	CollapseBundle(BundleProduct, BundleCharacteristic, TableName, Variant);
	
	BundleRows = BundleRows(BundleProduct, BundleCharacteristic, TableName, Variant);
	
	If BundleRows.Count() = 0 Then
		Return;
	EndIf;
	
	If NewCount = Undefined Then
		NewCount = OldCount + 1;
	EndIf;
	
	If OldCount = 0 Then
		ConversionFactor = 0;
	Else
		ConversionFactor = NewCount / OldCount;
	EndIf;
	
	For Each TableRow In BundleRows Do
		
		BaseComponentsRow = Undefined;
		
		For Each Component In BundleAttributes.BundlesComponents Do
			
			If Component.Products <> TableRow.Products
				Or Component.Characteristic <> TableRow.Characteristic
				Or (TableRow.Property("MeasurementUnit") And Component.MeasurementUnit <> TableRow.MeasurementUnit) Then
				Continue;
			EndIf;
			
			BaseComponentsRow = Component;
			Break;
			
		EndDo;
		
		If BaseComponentsRow <> Undefined Then
			
			TableRow.Quantity = BaseComponentsRow.Quantity * NewCount;
			TableRow.CostShare = BaseComponentsRow.CostShare * NewCount;
			
		Else
			// Proportional calculation
			TableRow.Quantity = TableRow.Quantity * ConversionFactor;
			TableRow.CostShare = TableRow.CostShare * ConversionFactor;
		EndIf;
		
	EndDo;
	
	If RecalculatePrices Then
		
		BundlePrice = Round(BundlePrice * ?(ConversionFactor=0, 1, ConversionFactor), 2);
		RecalculatePrices(BundleProduct, BundleCharacteristic, TableName, BundlePrice, BundleAttributes, Variant);
		
	EndIf;
	
EndProcedure

Procedure DeleteBundleComponent(BundleProduct, BundleCharacteristic, TableName, OldCount, Val NewCount = Undefined, Variant = Undefined, BundleAttributes = Undefined) Export
	
	If BundleAttributes = Undefined Then
		BundleAttributes = BundlesServerCall.BundleAttributes(BundleProduct, BundleCharacteristic);
	Else
		CollapseBundle(BundleProduct, BundleCharacteristic, BundleAttributes.BundlesComponents, Variant);
	EndIf;
	
	RecalculatePrices = TableName.Count() > 0
		And TableName[0].Property("Price")
		And BundleAttributes.BundlePricingStrategy <> PredefinedValue("Enum.ProductBundlePricingStrategy.PerComponentPricing")
		And BundleAttributes.BundlePricingStrategy <> PredefinedValue("Enum.ProductBundlePricingStrategy.EmptyRef");
	
	If RecalculatePrices Then
		
		BundlePrice = 0;
		BundleRows = BundleRows(BundleProduct, BundleCharacteristic, TableName, Variant);
		
		For Each TableRow In BundleRows Do
			BundlePrice = BundlePrice + TableRow.Price * TableRow.Quantity;
		EndDo;
		
	EndIf;
	
	CollapseBundle(BundleProduct, BundleCharacteristic, TableName, Variant);
	
	BundleRows = BundleRows(BundleProduct, BundleCharacteristic, TableName, Variant);
	If BundleRows.Count() = 0 Then
		Return;
	EndIf;
	
	If NewCount = Undefined Then
		NewCount = OldCount - 1;
	EndIf;
	
	If OldCount=0 Then
		ConversionFactor = 0;
	Else
		ConversionFactor = NewCount / OldCount;
	EndIf;
	
	RowsToDelete = New Array;
	For Each Row In BundleRows Do
		
		If Row.Quantity = 0 Then
			RowsToDelete.Add(Row);
			Continue;
		EndIf;
		
		BaseComponentsRow = Undefined;
		
		For Each Component In BundleAttributes.BundlesComponents Do
			
			If Component.Products <> Row.Products
				Or Component.Characteristic <> Row.Characteristic
				Or (Row.Property("MeasurementUnit") And Component.MeasurementUnit <> Row.MeasurementUnit) Then
				Continue;
			EndIf;
			
			BaseComponentsRow = Component;
			
			Break;
			
		EndDo;
		
		If BaseComponentsRow <> Undefined Then
			
			Row.Quantity = BaseComponentsRow.Quantity * NewCount;
			Row.CostShare = BaseComponentsRow.CostShare * NewCount;
			
		Else
			
			Row.Quantity = Row.Quantity * ConversionFactor;
			Row.CostShare = Row.CostShare * ConversionFactor;
			
		EndIf;
		
	EndDo;
	
	For Each Row In RowsToDelete Do
		BundleRows.Delete(BundleRows.Find(Row));
		TableName.Delete(Row);
	EndDo;
	
	If RecalculatePrices Then
		BundlePrice = Round(BundlePrice * ConversionFactor, 2);
		RecalculatePrices(BundleProduct, BundleCharacteristic, TableName, BundlePrice, BundleAttributes, Variant);
	EndIf;
	
EndProcedure

Procedure RoundingBundlePrice(BundlesComponents, DifferenceAmount, BundleProduct = Undefined, BundleCharacteristic = Undefined, Variant = Undefined) Export
	
	DifferenceAmount = Round(DifferenceAmount, 3);
	DifferenceAmount = Round(DifferenceAmount, 2, ?(DifferenceAmount < 0, RoundMode.Round15as20, RoundMode.Round15as10));
	If DifferenceAmount=0 Then
		Return;
	EndIf;
	
	Prices = False;
	For Each Component In BundlesComponents Do
		If ValueIsFilled(Component.Price) Then
			Prices = True;
			Break;
		EndIf;
	EndDo;
	
	If Not Prices Then
		Return;
	EndIf;
	
	// 1. Progressive rounding for the sum of the differences
	For Each ComponentsDescription In BundlesComponents Do
		
		If BundleProduct <> Undefined And ComponentsDescription.BundleProduct <> BundleProduct Then
			Continue;
		EndIf;
		
		If BundleCharacteristic <> Undefined And ComponentsDescription.BundleCharacteristic <> BundleCharacteristic Then
			Continue;
		EndIf;
		
		If Variant <> Undefined And ComponentsDescription.Variant <> Variant Then
			Continue;
		EndIf;
		
		If ComponentsDescription.Price = 0 Or ComponentsDescription.Quantity = 0 Then
			Continue;
		EndIf;
		
		If Round(DifferenceAmount, 2) = 0 Then
			Break;
		EndIf;
		
		RowDifference = Round(DifferenceAmount / ComponentsDescription.Quantity, 2);
		
		If RowDifference=0 Then
			Continue;
		EndIf;
		
		ComponentsDescription.Price = ComponentsDescription.Price + RowDifference;
		DifferenceAmount = DifferenceAmount - RowDifference * ComponentsDescription.Quantity;
		
	EndDo;
	
	// 2. Search for a line with a quantity equal to one
	If Round(DifferenceAmount, 2) <> 0 Then
		
		For Each ComponentsDescription In BundlesComponents Do
			
			If Not FoundedRow(ComponentsDescription, BundleProduct, BundleCharacteristic, Variant) Then
				Continue;
			EndIf;
			
			If ComponentsDescription.Quantity = 1 Then
				
				ComponentsDescription.Price = ComponentsDescription.Price + Round(DifferenceAmount, 2);
				DifferenceAmount = DifferenceAmount - Round(DifferenceAmount, 2);
				Break;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// 3. Allocated a separate row in the composition to adjust the rounding
	If Round(DifferenceAmount, 2) <> 0 Then
		
		ComponentsDescription = Undefined;
		ItemsCount = BundlesComponents.Count();
		
		For Counter = 1 To ItemsCount Do
			
			CurrentRow = BundlesComponents[ItemsCount - Counter];
			If Not FoundedRow(CurrentRow, BundleProduct, BundleCharacteristic, Variant) Then
				Continue;
			EndIf;
			
			If CurrentRow.Quantity > 1 Then
				ComponentsDescription = CurrentRow;
				Break;
			EndIf;
			
		EndDo;
		
		If ComponentsDescription <> Undefined Then
			
			If TypeOf(ComponentsDescription)=Type("Structure") Then
				
				NewRow = CommonClientServer.CopyStructure(ComponentsDescription);
				InsertIndex = BundlesComponents.Find(ComponentsDescription) + 1;
				
				If InsertIndex >= BundlesComponents.Count() Then
					BundlesComponents.Add(NewRow);
				Else
					BundlesComponents.Insert(InsertIndex, NewRow);
				EndIf;
				
			Else
				
				InsertIndex = BundlesComponents.IndexOf(ComponentsDescription) + 1;
				
				If InsertIndex >= BundlesComponents.Count() Then
					NewRow = BundlesComponents.Add();
				Else
					NewRow = BundlesComponents.Insert(InsertIndex);
				EndIf;
				
				FillPropertyValues(NewRow, ComponentsDescription);
				
				If NewRow.Property("ConnectionKey") Then
					NewRow.ConnectionKey = 0;
				EndIf;
				
				If NewRow.Property("ConnectionKeyForMarkupsDiscounts") Then
					NewRow.ConnectionKeyForMarkupsDiscounts = 0;
				EndIf;
				
				FillNewRowAttributes(BundlesComponents, NewRow);
				
			EndIf;
			
			NewRow.Quantity = 1;
			
			If ComponentsDescription.Quantity > 1 Then
				ComponentsDescription.Quantity = ComponentsDescription.Quantity - 1;
			EndIf;
			
			NewRow.Price = NewRow.Price + Round(DifferenceAmount, 2);
			NewRow.CostShare = 0;
			
			If TypeOf(NewRow) = Type("Structure") Then
				NewRow.Insert("PriceUpdate", True);
			EndIf;
			
		EndIf;
	EndIf;
	
EndProcedure

Procedure FillNewRowAttributes(TableName, NewRow) Export
	
	If NewRow.Property("ConnectionKey") Then
		DriveClientServer.FillConnectionKey(TableName, NewRow, "ConnectionKey");
	EndIf;
	
	If NewRow.Property("ConnectionKeyForMarkupsDiscounts") Then
		DriveClientServer.FillConnectionKey(TableName, NewRow, "ConnectionKeyForMarkupsDiscounts");
	EndIf;
	
EndProcedure

Procedure ReplaceInventoryLineWithBundleData(Object, TableName, TableRow, StructureData) Export
	
	TablePart = Object[TableName];
	
	UseVariants = (IsColumn(TablePart, TableRow, "Variant") And TablePart.Total("Variant") > 0);
	IsWorkOrder = (TypeOf(Object.Ref) =  Type("DocumentRef.WorkOrder"));
	CalculateAmount = (TableRow.Property("Amount"));
	
	Index = TablePart.IndexOf(TableRow);
	BundesCount = ?(TableRow.Quantity = 0, 1, TableRow.Quantity);
	
	CalculationParameters = New Structure;
	
	If CalculateAmount Then
		CalculationParameters.Insert("ResetFlagDiscountsAreCalculated", True);
		CalculationParameters.Insert("AmountIncludesVAT", Object.AmountIncludesVAT);
		CalculationParameters.Insert("CalculateDiscounts", Object.Property("DiscountMarkupKind"));
	EndIf;
	
	Index = TablePart.IndexOf(TableRow);
	BundesCount = ?(TableRow.Quantity = 0, 1, TableRow.Quantity);
	RowsWereAdded = False;
	
	FilterStructure = New Structure;
	FilterStructure.Insert("BundleProduct", TableRow.Products);
	FilterStructure.Insert("BundleCharacteristic", TableRow.Characteristic);
	
	If UseVariants Then
		FilterStructure.Insert("Variant", TableRow.Variant);
	EndIf;
	
	AddedRows = Object.AddedBundles.FindRows(FilterStructure);
	
	If AddedRows.Count() = 0 Then
		
		If StructureData.BundlesComponents.Count() = 0 Then
			CommonClientServer.MessageToUser(NStr("en = 'Bundles components not filled'; ru = 'Компоненты набора не заполнены';pl = 'Nie wypełniono składników zestawu';es_ES = 'Los componentes de paquetes no están rellenados';es_CO = 'Los componentes de paquetes no están rellenados';tr = 'Ürün seti malzemeleri doldurulmadı';it = 'Componenti del kit di prodotti non compilati';de = 'Bündelt nicht gefüllten Materialbestand'"));
			Return;
		EndIf;
		
		// Adding components from a bundle.
		AddedRow = Object.AddedBundles.Add();
		FillPropertyValues(AddedRow, FilterStructure);
		
		For Each ComponentsDescription In StructureData.BundlesComponents Do
			
			SearchStructure = New Structure("Products, Characteristic");
			FillPropertyValues(SearchStructure, ComponentsDescription);
			
			If IsColumn(TablePart, TableRow, "MeasurementUnit") Then
				SearchStructure.Insert("MeasurementUnit", ComponentsDescription.MeasurementUnit);
			EndIf;
			
			SearchStructure.Insert("BundleProduct", TableRow.Products);
			SearchStructure.Insert("BundleCharacteristic", TableRow.Characteristic);
			
			If UseVariants Then
				SearchStructure.Insert("Variant", TableRow.Variant);
			EndIf;
			
			If StructureData.Property("DiscountMarkupPercent") Then
				SearchStructure.Insert("DiscountMarkupPercent", TableRow.DiscountMarkupPercent);
			EndIf;
			
			If ComponentsDescription.Property("PriceUpdate") And ComponentsDescription.PriceUpdate Then
				SearchStructure.Insert("Price", TableRow.Price);
			EndIf;
			
			FoundRows = TablePart.FindRows(SearchStructure);
			If FoundRows.Count() > 0 Then
				
				NewRow = FoundRows[0];
				
				If StructureData.BundlePricingStrategy <> PredefinedValue("Enum.ProductBundlePricingStrategy.PerComponentPricing") 
					And CalculateAmount Then
					
					If (NewRow.Quantity + ComponentsDescription.Quantity) <> 0
						And (NewRow.Price <> ComponentsDescription.Price) Then
						
						NewRow.Price = (NewRow.Quantity * NewRow.Price + ComponentsDescription.Quantity * ComponentsDescription.Price)
										/ (NewRow.Quantity + ComponentsDescription.Quantity);
						
					EndIf;
					
				EndIf;
				
			Else
				
				NewRow = TablePart.Insert(Index);
				Index = Index + 1;
				FillPropertyValues(NewRow, ComponentsDescription, , "Quantity, CostShare");
				NewRow.BundleProduct = TableRow.Products;
				NewRow.BundleCharacteristic = TableRow.Characteristic;
				
				If UseVariants Then
					NewRow.Variant = TableRow.Variant;
				EndIf;
				
				If StructureData.Property("DiscountMarkupPercent") Then
					NewRow.DiscountMarkupPercent = StructureData.DiscountMarkupPercent;
				EndIf;
				
				If IsWorkOrder And Object.WorkKindPosition=PredefinedValue("Enum.AttributeStationing.InTabularSection") Then
					NewRow.WorkKind = TableRow.WorkKind;
				EndIf;
				
				If IsColumn(TablePart, NewRow, "BundlePicture") Then
					NewRow.BundlePicture = True;
				EndIf;
				
				If IsColumn(TablePart, NewRow, "ConnectionKey") Then
					DriveClientServer.FillConnectionKey(TablePart, NewRow, "ConnectionKey");
				EndIf;
				
				If IsColumn(TablePart, NewRow, "Check") Then
					NewRow.Check = TableRow.Check;
				EndIf;
				
				RowsWereAdded = True;
				
			EndIf;
			
			NewRow.Quantity = NewRow.Quantity + ComponentsDescription.Quantity * BundesCount;
			
			If IsColumn(TablePart, NewRow, "Reserve") Then
				NewRow.Reserve = NewRow.Reserve + ComponentsDescription.Quantity * TableRow.Reserve;
			EndIf;
			
			If IsWorkOrder And IsColumn(TablePart, NewRow, "ShipmentReserve") Then
				NewRow.ShipmentReserve = NewRow.ShipmentReserve + ComponentsDescription.Quantity * TableRow.ShipmentReserve;
			EndIf;
			
			NewRow.CostShare = NewRow.CostShare + ComponentsDescription.CostShare * BundesCount;
			
			If CalculateAmount Then
				CalculateAmountInTableRow(NewRow, CalculationParameters);
			EndIf;
			
			If IsColumn(TablePart, NewRow, "Cell") Then
				If ValueIsFilled(ComponentsDescription.Cell) Then
					NewRow.Cell = ComponentsDescription.Cell;
				Else
					NewRow.Cell = Object.Cell;
				EndIf;
			EndIf;
			
			If IsColumn(TablePart, NewRow, "ProductsCharacteristicAndBatch") Then
				NewRow.ProductsCharacteristicAndBatch = TrimAll("" + NewRow.Products)
					+ ?(NewRow.Characteristic.IsEmpty(), "", ". " + NewRow.Characteristic)
					+ ?(NewRow.Batch.IsEmpty(), "", ". " + NewRow.Batch);
			EndIf;
				
			If IsColumn(TablePart, NewRow, "DataOnRow") Then
				DiscountAmountStrings = (NewRow.Quantity * NewRow.Price) - NewRow.Amount;
				If DiscountAmountStrings <> 0 Then
					DiscountPercent = Format(DiscountAmountStrings * 100 / (NewRow.Quantity * NewRow.Price), "NFD=2");
					DiscountTextTemplate = "%1 %2 (%3 %)";
					DiscountText = StringFunctionsClientServer.SubstituteParametersToString(
						DiscountTextTemplate,
						?(DiscountAmountStrings > 0, " - " + DiscountAmountStrings, " + " + (-DiscountAmountStrings)),
						Object.DocumentCurrency,
						?(DiscountAmountStrings > 0, " - " + DiscountPercent, " + " + (-DiscountPercent)));
				Else
					DiscountText = "";
				EndIf;
				DataOnRowTemplate = "%1 X %2 = %3";
				NewRow.DataOnRow = StringFunctionsClientServer.SubstituteParametersToString(
					DataOnRowTemplate,
					"" + NewRow.Price + " " + Object.DocumentCurrency,
					"" + NewRow.Quantity + " " + NewRow.MeasurementUnit + DiscountText,
					"" + NewRow.Amount + " " + Object.DocumentCurrency);
			EndIf;
			
		EndDo;
		
	Else
		
		// Adding bundle instance
		AddedRow = AddedRows[0];
		AddBundleComponent(
			TableRow.Products,
			TableRow.Characteristic,
			TablePart,
			AddedRow.Quantity,
			AddedRow.Quantity + BundesCount,
			?(UseVariants, TableRow.Variant, Undefined),
			StructureData);
		
		BundleRows = TablePart.FindRows(FilterStructure);
			
		If CalculateAmount Then
			For Each BundleRow In BundleRows Do
				CalculateAmountInTableRow(BundleRow, CalculationParameters);
			EndDo;
		EndIf;
		
	EndIf;
	
	AddedRow.Quantity = AddedRow.Quantity + BundesCount;
	
	TablePart.Delete(TableRow);
	
EndProcedure

#EndRegion

#Region Private

Procedure CollapseBundle(BundleProduct, BundleCharacteristic, TableName, Variant = Undefined)
	
	BundleRows = BundleRows(BundleProduct, BundleCharacteristic, TableName, Variant);
	
	If BundleRows.Count() = 0 Then
		Return;
	EndIf;
	
	RowsToDelete = New Array;
	
	For Each BundleRow In BundleRows Do
		
		If BundleRow.Quantity = 0 Then
			// Processed string
			Continue;
		EndIf;
		
		For Each SearchString In BundleRows Do
			
			If BundleRow = SearchString Then
				Continue;
			EndIf;
			
			If BundleRow.Products <> SearchString.Products 
				Or BundleRow.Characteristic <> SearchString.Characteristic
				Or (BundleRow.Property("MeasurementUnit") And BundleRow.MeasurementUnit <> SearchString.MeasurementUnit) Then
				Continue;
			EndIf;
			
			BundleRow.Quantity = BundleRow.Quantity + SearchString.Quantity;
			
			BundleRow.CostShare = BundleRow.CostShare + SearchString.CostShare;
			SearchString.Quantity = 0;
			RowsToDelete.Add(SearchString);
			
		EndDo;
		
	EndDo;
	
	For Each BundleRow In RowsToDelete Do
		
		If TypeOf(TableName) = Type("Array") Then
			If TableName.Find(BundleRow) <> Undefined Then
				TableName.Delete(TableName.Find(BundleRow));
			EndIf;
		Else
			TableName.Delete(BundleRow);
		EndIf;
		
	EndDo;
	
EndProcedure

Function BundleRows(BundleProduct, BundleCharacteristic, TableName, Variant = Undefined)
	
	If TypeOf(TableName)=Type("Array") Then
		
		BundleRows = New Array;
		
		For Each TableRow In TableName Do
			If Not FoundedRow(TableRow, BundleProduct, BundleCharacteristic, Variant) Then
				Continue;
			EndIf;
			BundleRows.Add(TableRow);
		EndDo;
		
	Else
		
		FilterStructure = New Structure;
		FilterStructure.Insert("BundleProduct", BundleProduct);
		FilterStructure.Insert("BundleCharacteristic", BundleCharacteristic);
		
		If Variant <> Undefined Then
			FilterStructure.Insert("Variant", Variant);
		EndIf;
		
		BundleRows = TableName.FindRows(FilterStructure);
		
	EndIf;
	
	Return BundleRows;
	
EndFunction

Function FoundedRow(BundleRow, BundleProduct, BundleCharacteristic, Variant=Undefined)
	
	If BundleProduct <> Undefined
		And BundleRow.Property("BundleProduct")
		And BundleRow.BundleProduct <> BundleProduct Then
		Return False;
	EndIf;
	
	If BundleCharacteristic <> Undefined
		And BundleRow.Property("BundleCharacteristic")
		And BundleRow.BundleCharacteristic <> BundleCharacteristic Then
		Return False;
	EndIf;
	
	If Variant <> Undefined
		And BundleRow.Property("Variant")
		And BundleRow.Variant <> Variant Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Procedure RecalculatePrices(BundleProduct, BundleCharacteristic, TableName, BundlePrice, BundleAttributes, Variant = Undefined)
	
	BundleRows = BundleRows(BundleProduct, BundleCharacteristic, TableName, Variant);
	If BundleRows.Count() = 0 Then
		Return;
	EndIf;
	
	// Bundle price recalculation
	CalculationBase = 0;
	
	For Each Row In BundleRows Do
		
		IsWorks = Row.Property("Multiplicity");
		
		If BundleAttributes.BundlePricingStrategy
				= PredefinedValue("Enum.ProductBundlePricingStrategy.BundlePriceProratedByPrices") Then
			CalculationBase = CalculationBase + Row.Price * Row.Quantity;
		ElsIf BundleAttributes.BundlePricingStrategy
				= PredefinedValue("Enum.ProductBundlePricingStrategy.BundlePriceProratedByComponentsCost") Then
			CalculationBase = CalculationBase + Row.CostShare;
		EndIf;
		
	EndDo;
	
	If CalculationBase > 0 Then
		
		NewBundlePrice = 0;
		
		For Each Row In BundleRows Do
			
			IsWorks = Row.Property("Multiplicity");
			
			If Row.Quantity * ?(IsWorks, Row.Multiplicity, 1) = 0 Then
				Continue;
			EndIf;
			
			If BundleAttributes.BundlePricingStrategy
				= PredefinedValue("Enum.ProductBundlePricingStrategy.BundlePriceProratedByPrices") Then
				Row.Price = Round(BundlePrice * Row.Price * Row.Quantity / CalculationBase / Row.Quantity, 2);
			ElsIf BundleAttributes.BundlePricingStrategy
				= PredefinedValue("Enum.ProductBundlePricingStrategy.BundlePriceProratedByComponentsCost") Then
				Row.Price = Round(BundlePrice * Row.CostShare / CalculationBase / Row.Quantity, 2);
			EndIf;
			
			NewBundlePrice = NewBundlePrice + (Row.Price * Row.Quantity);
		
		EndDo;
		
		If NewBundlePrice <> BundlePrice Then
			
			DifferenceAmount = BundlePrice - NewBundlePrice;
			RoundingBundlePrice(TableName, DifferenceAmount, BundleProduct, BundleCharacteristic, Variant);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function IsColumn(TableName, TableRow, ColumnName)
	
	If TypeOf(TableRow)=Type("FormDataCollectionItem") Then
		// Call from the form
		Return TableRow.Property(ColumnName);
	Else
		Return False;
	EndIf;
	
EndFunction

Procedure CalculateAmountInTableRow(TabularSectionRow, CalculationParameters) Export

	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
	If CalculationParameters.CalculateDiscounts Then
		If TabularSectionRow.DiscountMarkupPercent = 100 Then
			TabularSectionRow.Amount = 0;
		ElsIf TabularSectionRow.DiscountMarkupPercent <> 0
				AND TabularSectionRow.Quantity <> 0 Then
			TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		EndIf;
	EndIf;
	
	VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
	
	TabularSectionRow.VATAmount = ?(CalculationParameters.AmountIncludesVAT, 
									  TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
									  TabularSectionRow.Amount * VATRate / 100);
	
	TabularSectionRow.Total = TabularSectionRow.Amount + ?(CalculationParameters.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
	
	// AutomaticDiscounts.
	If CalculationParameters.CalculateDiscounts Then
		TabularSectionRow.AutomaticDiscountsPercent = 0;
		TabularSectionRow.AutomaticDiscountAmount = 0;
		TabularSectionRow.TotalDiscountAmountIsMoreThanAmount = False;
	EndIf;
	// End AutomaticDiscounts
	
EndProcedure

#EndRegion