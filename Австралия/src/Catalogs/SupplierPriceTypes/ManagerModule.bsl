#If Server Or ThickClientOrdinaryApplication Then

#Region EventHandlers

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	NativeLanguagesSupportServer.ChoiceDataGetProcessing(
		ChoiceData,
		Parameters,
		StandardProcessing,
		Metadata.Catalogs.SupplierPriceTypes);
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationGetProcessing(Data, Presentation, StandardProcessing);
	
EndProcedure

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	NationalLanguageSupportClientServer.PresentationFieldsGetProcessing(Fields, StandardProcessing);
	
EndProcedure

#EndRegion

#Region ProgramInterface

// Function receives the default counterparty price type
//
Function CounterpartyDefaultPriceKind(Counterparty) Export
	
	Return ?(ValueIsFilled(Counterparty) AND ValueIsFilled(Counterparty.ContractByDefault),
				Counterparty.ContractByDefault.SupplierPriceTypes,
				Undefined);
	
EndFunction

// Function finds any first price type of specified counterparty
//
Function FindAnyFirstKindOfCounterpartyPrice(Counterparty) Export
	
	If Not ValueIsFilled(Counterparty) Then
		
		Return Undefined;
		
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED TOP 1 
	|	SupplierPriceTypes.Ref AS Ref
	|FROM
	|	Catalog.SupplierPriceTypes AS SupplierPriceTypes
	|WHERE
	|	SupplierPriceTypes.Counterparty = &Counterparty");
	
	Query.SetParameter("Counterparty", Counterparty);
	Selection = Query.Execute().Select();
	
	Return ?(Selection.Next(), Selection.Ref, Undefined);
	
EndFunction

// Function creates a price type of specified counterparty
//
Function CreateSupplierPriceTypes(Counterparty, SettlementsCurrency) Export
	
	If Not ValueIsFilled(Counterparty)
		OR Not ValueIsFilled(SettlementsCurrency) Then
		
		Return Undefined;
		
	EndIf;
	
	FillStructure = New Structure("Description, Owner, PriceCurrency, PriceIncludesVAT, Comment", 
		Left("Prices for " + Counterparty.Description, 25),
		Counterparty,
		SettlementsCurrency,
		True,
		"Registers the incoming prices. It is created automatically.");
		
	NewSupplierPriceTypes = Catalogs.SupplierPriceTypes.CreateItem();
	FillPropertyValues(NewSupplierPriceTypes, FillStructure);
	NewSupplierPriceTypes.Write();
	
	Return NewSupplierPriceTypes.Ref;
	
EndFunction

#EndRegion

#EndIf