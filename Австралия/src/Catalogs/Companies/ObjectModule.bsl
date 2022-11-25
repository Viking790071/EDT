#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	FillByDefault();

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Not IsNew() And WorkWithVATServerCall.CompanyIsRegisteredForVAT(Ref, CurrentSessionDate(), Undefined) Then
		CheckedAttributes.Add("VATNumbers.VATNumber");
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	// 1. Actions performed always, including the exchange of data
	
	If IsNew() Then
		
		// The "Ref" is certainly not filled.
		// However, reference may be transmitted in the During the exchange.
		
		NewObjectRef = GetNewObjectRef();
		If NewObjectRef.IsEmpty() Then
			SetNewObjectRef(Catalogs.Companies.GetRef());
		EndIf;
		
	EndIf;
	
	// No execute action in the data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// 2. No further action is performed when recording data exchange mechanism is initiated
	
	// Check the possibility of changes
	If IsNew() AND Not GetFunctionalOption("UseSeveralCompanies") Then
		CommonClientServer.MessageToUser(NStr("en = 'In the application, accounting by several companies is disabled.'; ru = 'В программе отключен учет по нескольким организациям.';pl = 'W programie jest wyłączona ewidencja kilku firm.';es_ES = 'En la aplicación, la contabilidad por varias empresas está desactivada.';es_CO = 'En la aplicación, la contabilidad por varias empresas está desactivada.';tr = 'Uygulamada, birçok iş yerine göre muhasebe devre dışı bırakılmıştır.';it = 'Nella domanda, la contabilità da diverse società è disabilitato.';de = 'In der Anwendung ist die Buchhaltung von mehreren Firmen deaktiviert.'"));
		Cancel = True;
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	// 3. Other actions
	
	// Fill default VAT ID
	If Not ValueIsFilled(VATNumber) And VATNumbers.Count() > 0 Then
		VATNumber = Catalogs.Companies.FindDefaultVATNumber(Ref, VATNumbers);
	ElsIf VATNumbers.Count() = 0 Then
		NewRow = VATNumbers.Add();
		FillPropertyValues(NewRow, ThisObject);
	EndIf;
	
	BringDataToConsistentState();
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	BankAccountByDefault	= Undefined;
	LogoFile				= Undefined;
	FileFacsimilePrinting	= Undefined;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	// No execute action in the data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	CurrencyRateOperations.CheckCurrencyRateAvailabilityFor01_01_1980(Ref);	
	
EndProcedure

#EndRegion

#Region Private

Procedure FillByDefault()
	
	If Not ValueIsFilled(BusinessCalendar) Then
		BusinessCalendar = DriveServer.GetFiveDaysCalendar();
	EndIf;
		
	If Not ValueIsFilled(PettyCashByDefault) Then
		PettyCashByDefault = Catalogs.CashAccounts.GetPettyCashByDefault();
	EndIf;
	
	If Not ValueIsFilled(ExchangeRateMethod) Then
		DefaultCompany = DriveReUse.GetUserDefaultCompany();
		If Not ValueIsFilled(DefaultCompany) Then
			DefaultCompany = Catalogs.Companies.MainCompany;
		EndIf;
		ExchangeRateMethod = Common.ObjectAttributeValue(DefaultCompany, "ExchangeRateMethod");
	EndIf;
	
EndProcedure

// Procedure coordinates the state some attributes of the object depending on the other
//
Procedure BringDataToConsistentState()
	
	If LegalEntityIndividual = Enums.CounterpartyType.LegalEntity Then
		
		Individual = Undefined;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf