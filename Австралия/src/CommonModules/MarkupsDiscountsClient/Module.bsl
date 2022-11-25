
#Region AppliedDiscounts

// The procedure opens the form of discounts details calculated by the current line of spreadsheet part
//
// Parameters
//  CurrentData  - TabularSectionRow - String for which it is
//  required to open discounts details Object  - FormData - Object for which you need to
//  open a form of discount details Form  - Form - Object form
//
Procedure OpenFormAppliedDiscounts(CurrentData, Object, Form) Export
	
	If CurrentData <> Undefined Then
	
		StructureCurrentData = New Structure;
		StructureCurrentData.Insert("ConnectionKey",         ?(CurrentData.Property("ConnectionKeyForMarkupsDiscounts"), CurrentData.ConnectionKeyForMarkupsDiscounts, CurrentData.ConnectionKey)); // Job order has 2 SP.
		StructureCurrentData.Insert("Products",      CurrentData.Products);
		StructureCurrentData.Insert("Characteristic",    CurrentData.Characteristic);
		StructureCurrentData.Insert("ManualDiscountAmount", CurrentData.Price * CurrentData.Quantity * CurrentData.DiscountMarkupPercent / 100);
		StructureCurrentData.Insert("AmountWithoutDiscount",    CurrentData.Price * CurrentData.Quantity);
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("Object", Object);
		ParametersStructure.Insert("Title", NStr("en = 'Discounts applied to the line'; ru = 'Скидки применены к строке';pl = 'Rabaty zastosowane do wiersza';es_ES = 'Descuentos aplicados a la línea';es_CO = 'Descuentos aplicados a la línea';tr = 'Satıra uygulanan indirimler';it = 'Sconti applicati alla linea';de = 'Rabatte auf die Linie angewendet'"));
		ParametersStructure.Insert("CurrentData", StructureCurrentData);
		ParametersStructure.Insert("AddressDiscountsAppliedInTemporaryStorage",          Form.AddressDiscountsAppliedInTemporaryStorage);
		ParametersStructure.Insert("ShowInformationAboutDiscountsOnRow",                True);
		ParametersStructure.Insert("ShowInformationAboutRowCalculationDiscount",          True);
		ParametersStructure.Insert("ShowInformationAboutDiscountsCalculationInDocumentInGeneral", False);
		ParametersStructure.Insert("ShowException", 								True);
		
		OpenForm("CommonForm.AppliedDiscounts", ParametersStructure, Form, Form.UUID);
	
	EndIf;
	
EndProcedure

#EndRegion