
#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	ReadOnly = Not AllowedEditDocumentPrices;
	
	ObjectsVersioning.OnCreateAtServer(ThisForm);
	
	ReceiveConfigurationRestrictions();
	
	DiscountsMarkupsServerOverridable.GetDiscountProvidingConditionsValuesList(Items.AssignmentCondition.ChoiceList);
	
	AssignmentConditionOnChangeAtServer();
	ApplicationCriterionForSalesVolumeOnChangeAtServer();
	
	If Not ValueIsFilled(Object.Ref) Then
		Object.Description = FormAutoNamingAtServer();
	Else
		FormAutoNamingAtServer();
	EndIf;
	
	FillSignsInTP();
	
	For Each NameVariant In Items.Description.ChoiceList Do
		If Object.Description = NameVariant.Value Then
			UsedAutoDescription = True;
		EndIf;
	EndDo;
	
	Modified = False;
	
	DriveClientServer.SetPictureForComment(Items.CommentGroup, Object.Comment);
	
	// Handler of the Additional reports and data processors subsystem
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	
	//Conditional appearance
	SetConditionalAppearance();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillSignsInTP();
	
	DiscountRecipientTypePrevious = DiscountRecipientType;

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure


// The procedure fills in values of the CharacteristicsUsed and IsFolder attributes (added in form)
//
&AtServer
Procedure FillSignsInTP()

	For Each CurrentRow In Object.PurchaseKit Do
		CurrentRow.CharacteristicsAreUsed = CurrentRow.Products.UseCharacteristics;
		CurrentRow.IsFolder = CurrentRow.Products.IsFolder;
	EndDo;
	For Each CurrentRow In Object.SalesFilterByProducts Do
		CurrentRow.CharacteristicsAreUsed = CurrentRow.Products.UseCharacteristics;
		CurrentRow.IsFolder = CurrentRow.Products.IsFolder;
	EndDo;

EndProcedure

// Procedure - BeforeWrite event handler.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	UpdateAutoNaming(Modified);
	
EndProcedure

// Procedure - handler of the AfterWriteAtServer event.
//
&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillSignsInTP();

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("AssignmentCondition_Record");
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

// Procedure - handler of the OnChange event of the RestrictionCurrency item.
//
&AtClient
Procedure RestrictionCurrencyOnChange(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - handler of the OnChange event of AssignmentConditionValue form item.
//
&AtClient
Procedure AssignmentConditionValueOnChange(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - handler of the AutoPick event of the Name item.
//
&AtClient
Procedure NameAutoFilter(Item, Text, ChoiceData, Parameters, Wait, StandardProcessing)
	
	If Wait = 0 Then
		FormAutoNamingAtClient();
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange item Name.
//
&AtClient
Procedure DescriptionOnChange(Item)
	
	DescriptionChangedByUser = True;
	
EndProcedure

// Procedure - handler of the OnChange event of the RestrictionField item.
//
&AtClient
Procedure RestrictionAreaOnChange(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - handler of the OnChange event of the ComparisonType item.
//
&AtClient
Procedure ComparisonTypeOnChange(Item)
	UpdateAutoNaming(True);
EndProcedure

// Procedure - handler of the OnChange event of AssignmentCondition form item.
//
&AtClient
Procedure AssignmentConditionOnChange(Item)
	
	AssignmentConditionOnChangeAtServer();
	Object.Description = "";
	
	UpdateAutoNaming(True);
	
EndProcedure

// Server part the AssignmentConditionOnChange procedure - handler of the OnChange event of AssignmentCondition form item.
//
&AtServer
Procedure AssignmentConditionOnChangeAtServer()
	
	Items.ForOneTimeSalesVolume.Visible             = (Object.AssignmentCondition = Enums.DiscountCondition.ForOneTimeSalesVolume);
	Items.ForKitPurchase.Visible                = (Object.AssignmentCondition = Enums.DiscountCondition.ForKitPurchase);
	
	Items.RestrictionArea.Enabled = True;
	
EndProcedure

// Procedure - handler of the OnChange event of the UseRestrictionCriterionForSalesVolume form item.
//
&AtClient
Procedure ApplicationCriterionForSalesVolumeOnChange(Item)
	
	ApplicationCriterionForSalesVolumeOnChangeAtServer();
	
	UpdateAutoNaming(True);
	
EndProcedure

// Server part the ApplicationCriterionForSalesVolumeOnChange procedure - handler of the OnChange event of the
// UseRestrictionCriterionForSalesVolume form item.
//
&AtServer
Procedure ApplicationCriterionForSalesVolumeOnChangeAtServer()
	
	If Object.UseRestrictionCriterionForSalesVolume = Enums.DiscountSalesAmountLimit.Quantity Then
		
		Items.RestrictionCurrency.Visible = False;
		
	Else
		
		Items.RestrictionCurrency.Visible = UsedCurrencies;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.CommentGroup, Object.Comment);
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region TableItemsEventHandlersFormsPurchaseKit

// Procedure - handler of the OnChange event in the Products column TP PurchaseKit form.
//
&AtClient
Procedure PurchaseKitProductsOnChange(Item)
	
	TabularSectionRow = Items.PurchaseKit.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity= 1;
	TabularSectionRow.CharacteristicsAreUsed = StructureData.CharacteristicsAreUsed;
	TabularSectionRow.IsFolder = StructureData.IsFolder;
	
EndProcedure

// Procedure - handler of the AfterDeletion event TP PurchaseKit form.
//
&AtClient
Procedure PurchaseKitAfterDeleteRow(Item)
	
	Object.Description = FormAutoNamingAtClient();
	
EndProcedure

// Procedure - handler of the OnEditEnd event TP PurchaseKit form.
//
&AtClient
Procedure PurchaseKitOnEditEnd(Item, NewRow, CancelEdit)
	
	Object.Description = FormAutoNamingAtClient();
	
EndProcedure

#EndRegion

#Region TableItemsEventHandlersSalesFilterByProducts

// Procedure - handler of the OnEditEnd event TP SalesSelectionByProducts form.
//
&AtClient
Procedure FilterSalesByProductsOnEditEnd(Item, NewRow, CancelEdit)
	
	Object.Description = FormAutoNamingAtClient();
	
EndProcedure

// Procedure - handler of the AfterDeletion event TP SalesFilterByProducts form.
//
&AtClient
Procedure FilterSalesByProductsAfterDeletion(Item)
	
	Object.Description = FormAutoNamingAtClient();
	
EndProcedure

// Procedure - handler of the OnChange event in the  Products column TP SalesFilterByProducts form.
//
&AtClient
Procedure FilterSalesByProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.SalesFilterByProducts.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.CharacteristicsAreUsed = StructureData.CharacteristicsAreUsed;
	TabularSectionRow.IsFolder = StructureData.IsFolder;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Procedure defines currency use.
//
&AtServer
Procedure ReceiveConfigurationRestrictions()

	UsedCurrencies = GetFunctionalOption("ForeignExchangeAccounting");

EndProcedure

// This function returns a brief content of the tabular section in row form.
//
&AtClient
Function TabularSectionDescriptionClient(TableName, AttributeName1, AttributeName2 = "", ItemCount = 0)

	TableLongDesc = "";
	
	ItemNumber = 0;
	For Each TableElement In Object[TableName] Do
		
		ItemNumber = ItemNumber + 1;
		If Not ItemCount = 0 AND (ItemCount + 1) = ItemNumber Then
			TableLongDesc = TableLongDesc + "... ,";
		ElsIf Not ItemCount = 0 AND (ItemCount + 1) < ItemNumber Then
			Break;
		Else
			AttributeValue2 = ?(ValueIsFilled(AttributeName2), TableElement[AttributeName2], "");
			TableLongDesc = TableLongDesc
				+ String(TableElement[AttributeName1])
				+ ?(ValueIsFilled(AttributeValue2), " - ", "")
				+ String(AttributeValue2)
				+ ", ";
		EndIf;
		
	EndDo;
	
	If Not TableLongDesc = "" Then
	
		TableLongDesc = Left(TableLongDesc, StrLen(TableLongDesc) - 2);
	
	EndIf;
	
	Return TableLongDesc;

EndFunction

// This function returns a brief content of the tabular section in row form.
//
&AtServer
Function TabularSectionDescriptionServer(TableName, AttributeName1, AttributeName2 = "", ItemCount = 0)

	TableLongDesc = "";
	
	ItemNumber = 0;
	For Each TableElement In Object[TableName] Do
		
		ItemNumber = ItemNumber + 1;
		If Not ItemCount = 0 AND (ItemCount + 1) = ItemNumber Then
			TableLongDesc = TableLongDesc + "... ,";
		ElsIf Not ItemCount = 0 AND (ItemCount + 1) < ItemNumber Then
			Break;
		Else
			AttributeValue2 = ?(ValueIsFilled(AttributeName2), TableElement[AttributeName2], "");
			TableLongDesc = TableLongDesc
				+ String(TableElement[AttributeName1])
				+ ?(ValueIsFilled(AttributeValue2), " - ", "")
				+ String(AttributeValue2)
				+ " ,";
		EndIf;
		
	EndDo;
	
	If Not TableLongDesc = "" Then
	
		TableLongDesc = Left(TableLongDesc, StrLen(TableLongDesc) - 2);
	
	EndIf;
	
	Return TableLongDesc;

EndFunction

// The procedure updates the name if the user did not change it manually.
//
&AtClient
Procedure UpdateAutoNaming(Refresh = True)
	
	If Not ValueIsFilled(Object.Description) OR (Refresh AND UsedAutoDescription AND Not DescriptionChangedByUser) Then
		Object.Description = FormAutoNamingAtClient();
		UsedAutoDescription = True;
	EndIf;
	
EndProcedure

// The function returns generated auto naming.
//
&AtClient
Function FormAutoNamingAtClient()
	
	Items.Description.ChoiceList.Clear();
	
	If Object.AssignmentCondition = PredefinedValue("Enum.DiscountCondition.ForOneTimeSalesVolume") Then
		
		If Object.UseRestrictionCriterionForSalesVolume = PredefinedValue("Enum.DiscountSalesAmountLimit.Quantity") Then
			Param1 = NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'");
			Param5 = NStr("en = 'unit'; ru = 'ед. изм.';pl = 'j.m.';es_ES = 'unidad';es_CO = 'unidad';tr = 'birim';it = 'unità';de = 'Einheit'");
		Else
			Param1 = Object.UseRestrictionCriterionForSalesVolume;
			Param5 = Object.RestrictionCurrency;
		EndIf;
		
		If Object.RestrictionArea = PredefinedValue("Enum.DiscountApplyingArea.InDocument") Then
			Param2 = NStr("en = 'in document'; ru = 'в документе';pl = 'w dokumencie';es_ES = 'en el documento';es_CO = 'en el documento';tr = 'belgede';it = 'nel documento';de = 'im Dokument'");
		Else
			Param2 = NStr("en = 'in line'; ru = 'в строке';pl = 'w wierszu';es_ES = 'en línea';es_CO = 'en línea';tr = 'satırda';it = 'nella linea';de = 'in Zeile'");
		EndIf;
		
		If Object.SalesFilterByProducts.Count() > 0 Then
			Param6 = StringFunctionsClientServer.SubstituteParametersToString(": %1",
				TabularSectionDescriptionClient("SalesFilterByProducts", "Products", "Characteristic"));
		Else
			Param6 = "";
		EndIf;
		
		DescriptionString = StringFunctionsClientServer.SubstituteParametersToString("%1 %2 %3 %4 %5%6",
			Param1,
			Param2,
			Object.ComparisonType,
			Object.RestrictionConditionValue,
			Param5,
			Param6);
		
	ElsIf Object.AssignmentCondition = PredefinedValue("Enum.DiscountCondition.ForKitPurchase") Then
		
		DescriptionString = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Bundle: %1'; ru = 'Набор: %1';pl = 'Zestaw: %1';es_ES = 'Paquete: %1';es_CO = 'Paquete: %1';tr = 'Ürün seti: %1';it = 'Kit di prodotti: %1';de = 'Artikelgruppe: %1'"),
			TabularSectionDescriptionClient("PurchaseKit", "Products", "Characteristic"));
		
	EndIf;
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	Return DescriptionString;
	
EndFunction

// The function returns generated auto naming.
//
&AtServer
Function FormAutoNamingAtServer()
	
	Items.Description.ChoiceList.Clear();
	
	If Object.AssignmentCondition = Enums.DiscountCondition.ForOneTimeSalesVolume Then
		
		If Object.UseRestrictionCriterionForSalesVolume = Enums.DiscountSalesAmountLimit.Quantity Then
			Param1 = NStr("en = 'Count-in'; ru = 'Количество';pl = 'Ilość';es_ES = 'Incluir';es_CO = 'Incluir';tr = 'Hesaba katmak/ dahil etmek';it = 'Conteggia in';de = 'Zählen-in'");
			Param5 = NStr("en = 'unit'; ru = 'ед. изм.';pl = 'j.m.';es_ES = 'unidad';es_CO = 'unidad';tr = 'birim';it = 'unità';de = 'Einheit'");
		Else
			Param1 = Object.UseRestrictionCriterionForSalesVolume;
			Param5 = Object.RestrictionCurrency;
		EndIf;
		
		If Object.RestrictionArea = Enums.DiscountApplyingArea.InDocument Then
			Param2 = NStr("en = 'in document'; ru = 'в документе';pl = 'w dokumencie';es_ES = 'en el documento';es_CO = 'en el documento';tr = 'belgede';it = 'nel documento';de = 'im Dokument'");
		Else
			Param2 = NStr("en = 'In line'; ru = 'в строке';pl = 'W wierszu';es_ES = 'En línea';es_CO = 'En línea';tr = 'Satırda';it = 'Nella linea';de = 'In zeile'");
		EndIf;
		
		If Object.SalesFilterByProducts.Count() > 0 Then
			Param6 = StringFunctionsClientServer.SubstituteParametersToString(": %1",
				TabularSectionDescriptionServer("SalesFilterByProducts", "Products", "Characteristic"));
		Else
			Param6 = "";
		EndIf;
		
		DescriptionString = StringFunctionsClientServer.SubstituteParametersToString("%1 %2 %3 %4 %5%6",
			Param1,
			Param2,
			Object.ComparisonType,
			Object.RestrictionConditionValue,
			Param5,
			Param6);
		
	ElsIf Object.AssignmentCondition = Enums.DiscountCondition.ForKitPurchase Then
		
		DescriptionString = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Set: %1'; ru = 'Набор: %1';pl = 'Zestaw: %1';es_ES = 'Establecer: %1';es_CO = 'Establecer: %1';tr = 'Ayarla: %1';it = 'Impostare: %1';de = 'Satz: %1'"),
			TabularSectionDescriptionServer("PurchaseKit", "Products", "Characteristic"));
		
	EndIf;
	
	Items.Description.ChoiceList.Add(DescriptionString);
	
	Return DescriptionString;
	
EndFunction

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorBlack	= StyleColors.TitleColorSettingsGroup;
	
	//PurchaseKitCharacteristic
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.PurchaseKit.CharacteristicsAreUsed");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorBlack);
	ItemAppearance.Appearance.SetParameterValue("MarkIncomplete", False);
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<variants are not used>'; ru = '<варианты не используются>';pl = '<warianty nie są używane>';es_ES = '<variantes no se han utilizado>';es_CO = '<variantes no se han utilizado>';tr = '<Varyantlar kullanılmaz>';it = '<varianti non utilizzate>';de = '<Varianten werden nicht verwendet>>'"));
	ItemAppearance.Appearance.SetParameterValue("ReadOnly", True);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("PurchaseKitCharacteristic");
	FieldAppearance.Use = True;
	
	//FilterSalesByProductsCharacteristic
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.SalesFilterByProducts.CharacteristicsAreUsed");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= False;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorBlack);
	ItemAppearance.Appearance.SetParameterValue("MarkIncomplete", False);
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<variants are not used>'; ru = '<варианты не используются>';pl = '<warianty nie są używane>';es_ES = '<variantes no se han utilizado>';es_CO = '<variantes no se han utilizado>';tr = '<Varyantlar kullanılmaz>';it = '<varianti non utilizzate>';de = '<Varianten werden nicht verwendet>>'"));
	ItemAppearance.Appearance.SetParameterValue("ReadOnly", True);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("FilterSalesByProductsCharacteristic");
	FieldAppearance.Use = True;
	
EndProcedure
#EndRegion

#Region CommonProceduresAndFunctions

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	StructureData.Insert("CharacteristicsAreUsed", StructureData.Products.UseCharacteristics);
	StructureData.Insert("IsFolder", StructureData.Products.IsFolder);
	
	Return StructureData;
	
EndFunction

#EndRegion