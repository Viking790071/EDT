#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		FillByCounterparty(FillingData);
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillByStructure(FillingData);
		
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Prices kind.
	If ValueIsFilled(DiscountMarkupKind) Then
		CheckedAttributes.Add("PriceKind");
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If DeletionMark And Not AdditionalProperties.Property("SkipDefaultContractDeletionMarkCheck") Then
		
		CounterpartyAttributesValues = Common.ObjectAttributesValues(Owner, "DeletionMark, ContractByDefault");
		
		If Not CounterpartyAttributesValues.DeletionMark AND CounterpartyAttributesValues.ContractByDefault = Ref Then
			MessageText = NStr("en = 'The default contract cannot be marked for deletion. Select another default contract for this counterparty and try again.'; ru = 'Договор контрагента, установленный в качестве основного, не может быть помечен на удаление.';pl = 'Umowa domyślna nie może zostać oznaczona do usunięcia. Wybierz inną domyślną umowę dla tego kontrahenta i spróbuj ponownie.';es_ES = 'El contrato por defecto no puede estar marcado para borrar. Seleccionar otro contrato por defecto para esta contraparte e intentar de nuevo.';es_CO = 'El contrato por defecto no puede estar marcado para borrar. Seleccionar otro contrato por defecto para esta contraparte e intentar de nuevo.';tr = 'Varsayılan sözleşme silinmek üzere işaretlenemez. Bu cari hesap için başka bir varsayılan sözleşme seçin ve tekrar deneyin.';it = 'Il contratto predefinito non può essere contrassegnato per l''eliminazione. Selezionare un altro contratto predefinito per questa controparte e riprovare.';de = 'Der Standardvertrag kann nicht zum Löschen markiert werden. Wählen Sie einen anderen Standardvertrag für diesen Geschäftspartner und versuchen Sie es erneut.'");
			CommonClientServer.MessageToUser(MessageText, Ref,,, Cancel);
		EndIf;
		
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED
	|	CounterpartyContracts.Ref AS Ref
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON CounterpartyContracts.Owner = Counterparties.Ref
	|WHERE
	|	CounterpartyContracts.Ref <> &Ref
	|	AND CounterpartyContracts.Owner = &Owner
	|	AND CounterpartyContracts.Company = &Company
	|	AND CounterpartyContracts.ContractKind = &ContractKind
	|	AND (NOT Counterparties.DoOperationsByContracts
	|			OR NOT &UseContracts)");
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Owner", Owner);
	Query.SetParameter("Company", Company);
	Query.SetParameter("ContractKind", ContractKind);
	Query.SetParameter("UseContracts", Constants.UseContractsWithCounterparties.Get());
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		MessageText = NStr("en = 'Cannot save the contract because billing details by contract are turned off for the selected counterparty. Turn them on in the counterparty details and then try again.'; ru = 'Не удалось сохранить договор. По указанному контрагенту не ведется учет взаиморасчетов по договорам. Включите взаиморасчеты по договорам и попробуйте снова.';pl = 'Nie można zapisać umowy, ponieważ szczegóły fakturowania są wyłączone dla wybranego kontrahenta. Włącz je w danych o kontrahencie, a następnie spróbuj ponownie.';es_ES = 'No se puede guardar el contrato, porque los detalles de facturación por el contrato están desactivados para la contraparte seleccionada. Activarlas en los detalles de la contraparte e intentar de nuevo.';es_CO = 'No se puede guardar el contrato, porque los detalles de facturación por el contrato están desactivados para la contraparte seleccionada. Activarlas en los detalles de la contraparte e intentar de nuevo.';tr = 'Seçilen cari hesap için sözleşmeye göre faturalama ayrıntılarının kapatılmasından dolayı sözleşme kaydedilemez. Cari hesap ayrıntılarında onları açıp tekrar deneyin.';it = 'Non è possibile salvare il contratto perchè i dettagli di fatturazione per contratto sono disattivati per la controparte selezionata. Attivateli nei dettagli della controparte e riprovate.';de = 'Der Vertrag kann nicht gespeichert werden, da die Abrechnungsdetails nach Vertrag für den ausgewählten Geschäftspartner deaktiviert sind. Schalten Sie sie in den Geschäftspartnerdetails ein und versuchen Sie es dann erneut.'");
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			,
			Cancel
		);
	EndIf;
	
	If Not IsNew() Then
		CheckChangePossibility(Cancel);
	EndIf;
	
	If ValueIsFilled(Ref) Then
		AdditionalProperties.Insert("DeletionMark", Ref.DeletionMark);
	EndIf;
	
	If Not IsFolder Then
		
		For Each Stage In StagesOfPayment Do
			If Stage.BaselineDate.IsEmpty() Then
				Stage.BaselineDate = Enums.BaselineDateForPayment.PostingDate;
			EndIf;
		EndDo;
		
	EndIf;
	
	If EarlyPaymentDiscounts.Count() > 0 AND ContractKind <> Enums.ContractType.WithCustomer
		AND ContractKind <> Enums.ContractType.WithVendor Then
		
		EarlyPaymentDiscounts.Clear();
		
	EndIf;
	
	Catalogs.InventoryOwnership.UpdateOnContractWrite(ThisObject);
	
EndProcedure

#EndRegion

#Region FillingProcedures

Procedure FillByCounterparty(FillingData)
	
	DoOperationsByContracts = Common.ObjectAttributeValue(FillingData, "DoOperationsByContracts");
	
	If Not ValueIsFilled(Company) Then
		
		CompanyByDefault = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If Not ValueIsFilled(CompanyByDefault) Then
			CompanyByDefault = Catalogs.Companies.MainCompany;
		EndIf;
		
		Company = CompanyByDefault;
		
	EndIf;
	
	WithoutContracts = (NOT Constants.UseContractsWithCounterparties.Get() OR NOT DoOperationsByContracts
		OR (AdditionalProperties.Property("IsNewMainContract") And AdditionalProperties.IsNewMainContract));
	
	Catalogs.CounterpartyContracts.FillContractFromCounterparty(FillingData, Company, ThisObject, WithoutContracts);
	
EndProcedure

Procedure FillByStructure(FillingData)
	
	FillPropertyValues(ThisObject, FillingData);
	
	If FillingData.Property("Owner") AND ValueIsFilled(FillingData.Owner) Then
		
		FillByCounterparty(FillingData.Owner);
		
	EndIf;
	
	If FillingData.Property("ContractKind") Then
		FillPropertyValues(ThisObject, FillingData, "ContractKind");
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure FillByDefault()
	
	If IsFolder Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(Responsible) Then
		Responsible = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainResponsible");
	EndIf;
	
	If Not ValueIsFilled(Department) Then
		Department = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainDepartment");
		If Not ValueIsFilled(Department) Then
			Department	= Catalogs.BusinessUnits.MainDepartment;	
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(BusinessLine) Then
		BusinessLine	= Catalogs.LinesOfBusiness.MainLine;	
	EndIf;
	
	If GetFunctionalOption("UsePurchaseOrderApproval") Then
		
		PurchaseOrdersApprovalType = Constants.PurchaseOrdersApprovalType.Get();
		If PurchaseOrdersApprovalType = Enums.PurchaseOrdersApprovalTypes.ConfigureForEachCounterparty Then
			
			LimitWithoutApproval = Constants.LimitWithoutPurchaseOrderApproval.Get();
			ApprovePurchaseOrders = LimitWithoutApproval > 0;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CheckChangePossibility(Cancel)
	
	PreviousContractKind = Common.ObjectAttributeValue(Ref, "ContractKind");
	
	If ContractKind <> PreviousContractKind Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 1
		|	AccountsReceivable.Contract AS Contract
		|FROM
		|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
		|WHERE
		|	AccountsReceivable.Contract = &Contract
		|
		|UNION ALL
		|
		|SELECT TOP 1
		|	AccountsPayable.Contract
		|FROM
		|	AccumulationRegister.AccountsPayable AS AccountsPayable
		|WHERE
		|	AccountsPayable.Contract = &Contract";
		
		Query.SetParameter("Contract", Ref);
		
		SetPrivilegedMode(True);
		
		QueryResult = Query.Execute();
		
		SetPrivilegedMode(False);
		
		If NOT QueryResult.IsEmpty() Then
			MessageText = NStr("en = 'There are entries in the infobase containing existing contract. Cannot change Counterparty role.'; ru = 'В базе присутствуют движения проводки по существующему договору. Изменение вида контракта запрещено.';pl = 'W polu baza informacyjna istnieją zapisy, zawierającej istniejący kontrakt. Nie można zmienić roli kontrahenta.';es_ES = 'Hay entradas en la infobase que contienen el contrato existente. No se puede cambiar el rol de la Contraparte.';es_CO = 'Hay entradas en la infobase que contienen el contrato existente. No se puede cambiar el rol de la Contraparte.';tr = 'Infobase''de mevcut sözleşmeyi içeren girişler var. Cari hesap rolü değiştirilemez.';it = 'Ci sono inserimenti nella base dati che contengono contratti esistenti. Non è possibile modificare il ruolo della Controparte.';de = 'Es gibt Einträge in der Infobase, die einen bestehenden Vertrag enthalten. Die Rolle des Geschäftspartners kann nicht geändert werden.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText,,,, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
