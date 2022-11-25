
#Region Public

Procedure FillPricesPrecisionChoiceList(Company, ChoiceList) Export
	
	MaxPricesPrecision = MaxPricesPrecision();
	MinPricesPrecision = PrecisionAppearanceClientServer.CompanyPrecision(Company);
	ChoiceList.Clear();
	
	While MinPricesPrecision <= MaxPricesPrecision Do
		
		ChoiceList.Add(MinPricesPrecision);
		MinPricesPrecision = MinPricesPrecision + 1;
		
	EndDo;
	
EndProcedure

Procedure SetPricesAppearance(ThisObject, Company, PricesFields) Export
	
	If ValueIsFilled(Company) Then
		ThisObject.PricesPrecision = PrecisionAppearanceClientServer.CompanyPrecision(Company);
	Else
		ThisObject.PricesPrecision = PrecisionAppearanceClientServer.MaxCompanyPrecision();
	EndIf;
	
	For Each PriceField In PricesFields Do
		
		PriceField.Format = "NFD= " + ThisObject.PricesPrecision + "";
		If PriceField.Type = FormFieldType.InputField Then
			PriceField.EditFormat = "NFD= " + ThisObject.PricesPrecision + "";
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function MaxPricesPrecision()
	Return 8;
EndFunction

#EndRegion
