
#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			OwnerType = Parameters.Filter.Owner.ProductsType;
			
			UseProductionSubsystem = Constants.UseProductionSubsystem.Get() Or Constants.UseKitProcessing.Get();
			
			If (OwnerType = Enums.ProductsTypes.Service
				OR (NOT UseProductionSubsystem AND OwnerType = Enums.ProductsTypes.InventoryItem)
				OR (NOT Constants.UseWorkOrders.Get() AND OwnerType = Enums.ProductsTypes.Work)) Then
			
				Message = New UserMessage();
				LabelText = NStr("en = 'BOM is not specified for products of the %EtcProducts% type.'; ru = 'Для номенклатуры типа %EtcProducts% спецификация не указывается!';pl = 'Specyfikacja materiałowa nie jest podana dla %EtcProducts% tego typu produktów.';es_ES = 'BOM no está especificado para los productos del tipo %EtcProducts%.';es_CO = 'BOM no está especificado para los productos del tipo %EtcProducts%.';tr = '%EtcProducts% türündeki ürünler için ürün reçetesi belirtilmedi.';it = 'La distinta base non è specificata per gli articoli del tipo %EtcProducts%.';de = 'Die Stückliste ist für Produkte der Art %EtcProducts%  nicht angegeben.'");
				LabelText = StrReplace(LabelText, "%EtcProducts%", OwnerType);
				Message.Text = LabelText;
				Message.Message();
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If Parameters.Filter.Property("ProductCharacteristic") Then
		Parameters.Filter.Delete("ProductCharacteristic");
	EndIf;
	
	If ValueIsFilled(Parameters.DateChoice) Then
		
		EmptyDate			= Date(1,1,1);
		ParameterDateChoice	= Parameters.DateChoice;
		
		BigGroupFilterItem				= List.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		BigGroupFilterItem.GroupType	= DataCompositionFilterItemsGroupType.OrGroup;
		
		GroupFilterItem					= BigGroupFilterItem.Items.Add(Type("DataCompositionFilterItemGroup"));
		GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("ValidityStartDate");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.LessOrEqual;
		DataFilterItem.RightValue		= ParameterDateChoice;
		DataFilterItem.Use				= True;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("ValidityEndDate");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.GreaterOrEqual;
		DataFilterItem.RightValue		= ParameterDateChoice;
		DataFilterItem.Use				= True;
		
		GroupFilterItem					= BigGroupFilterItem.Items.Add(Type("DataCompositionFilterItemGroup"));
		GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("ValidityStartDate");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
		DataFilterItem.RightValue		= EmptyDate;
		DataFilterItem.Use				= True;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("ValidityEndDate");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.GreaterOrEqual;
		DataFilterItem.RightValue		= ParameterDateChoice;
		DataFilterItem.Use				= True;
		
		GroupFilterItem					= BigGroupFilterItem.Items.Add(Type("DataCompositionFilterItemGroup"));
		GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("ValidityStartDate");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.LessOrEqual;
		DataFilterItem.RightValue		= ParameterDateChoice;
		DataFilterItem.Use				= True;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("ValidityEndDate");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
		DataFilterItem.RightValue		= EmptyDate;
		DataFilterItem.Use				= True;
		
		GroupFilterItem					= BigGroupFilterItem.Items.Add(Type("DataCompositionFilterItemGroup"));
		GroupFilterItem.GroupType		= DataCompositionFilterItemsGroupType.AndGroup;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("ValidityStartDate");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
		DataFilterItem.RightValue		= EmptyDate;
		DataFilterItem.Use				= True;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("ValidityEndDate");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
		DataFilterItem.RightValue		= EmptyDate;
		DataFilterItem.Use				= True;
		
	EndIf;
	
	If Parameters.Property("OperationKind") And ValueIsFilled(Parameters.OperationKind) Then
		
		BOMOperationKind = Catalogs.BillsOfMaterials.BOMOperationKind(Parameters.OperationKind);
		
		GroupFilterItem				= List.Filter.Items.Add(Type("DataCompositionFilterItemGroup"));
		GroupFilterItem.GroupType	= DataCompositionFilterItemsGroupType.OrGroup;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("OperationKind");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
		DataFilterItem.RightValue		= BOMOperationKind;
		DataFilterItem.Use				= True;
		
		DataFilterItem					= GroupFilterItem.Items.Add(Type("DataCompositionFilterItem"));
		DataFilterItem.LeftValue		= New DataCompositionField("OperationKind");
		DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
		DataFilterItem.RightValue		= Enums.OperationTypesProductionOrder.AssemblyDisassembly;
		DataFilterItem.Use				= True;
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
