
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Object.Company = DriveReUse.GetUserDefaultCompany();
	If Not ValueIsFilled(Object.Company) Then
		Object.Company = Catalogs.Companies.MainCompany;
	EndIf;
	CompanyOnChangeAtServer();
	
	Object.Date = CurrentDate();
	
	Object.PaymentMethod = Catalogs.PaymentMethods.Undefined;
	
	SetConditionalAppearance();
	
	SetPaymentTermsTitle();
	
	SetCounterpartyChoiceParameters();
	
	// StandardSubsystems.AttachableCommands
	PlacementParameters = AttachableCommands.PlacementParameters();
	Objects = New Array;
	Objects.Add(Metadata.Documents.SalesInvoice);
	PlacementParameters.Sources = Objects;
	PlacementParameters.CommandBar = Items.GroupGlobalCommandsReceipts;
	AttachableCommands.OnCreateAtServer(ThisObject, PlacementParameters);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetVisiblePaymentCalendar();
	SetVisiblePaymentMethod();
	
	SetRefreshNeeded(True);
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure StartDateOnChange(Item)
	
	If ValueIsFilled(Object.StartDate) And ValueIsFilled(Object.EndDate) And Object.StartDate > Object.EndDate Then
		Object.EndDate = Object.StartDate;
	EndIf;
	
	SetRefreshNeeded(True);
	
EndProcedure

&AtClient
Procedure EndDateOnChange(Item)
	
	If ValueIsFilled(Object.StartDate) And ValueIsFilled(Object.EndDate) And Object.StartDate > Object.EndDate Then
		Object.StartDate = Object.EndDate;
	EndIf;
	
	SetRefreshNeeded(True);
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	// Prices precision begin
	PrecisionAppearanceClient.SetPricesAppearance(ThisObject, Object.Company, PricesFields());
	// Prices precision end
	
	CompanyOnChangeAtServer();
	
	SetRefreshNeeded(True);
	
EndProcedure

&AtClient
Procedure DepartmentOnChange(Item)
	
	SetRefreshNeeded(True);
	
EndProcedure

&AtClient
Procedure FilterCounterpartiesOnChange(Item)
	
	SetRefreshNeeded(True);
	
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	
	SetRefreshNeeded(True);
	
EndProcedure

&AtClient
Procedure SetPaymentTermsOnChange(Item)
	
	If Object.SetPaymentTerms Then
		
		NewLine = Object.PaymentCalendar.Add();
		NewLine.PaymentPercentage = 100;
		
		SwitchTypeListOfPaymentCalendar = 0;
		SetVisiblePaymentCalendar();
		
		SetEnablePaymentTerms();
		
	ElsIf Object.PaymentCalendar.Count() > 0 Then
		
		Notify = New NotifyDescription("ClearPaymentCalendarContinue", ThisObject);
		
		QueryText = NStr("en = 'The payment terms will be cleared. Do you want to continue?'; ru = '?????????????? ???????????? ?????????? ??????????????. ?????????????????????';pl = 'Warunki p??atno??ci zostan?? wyczyszczone. Czy chcesz kontynuowa???';es_ES = 'Los t??rminos de pago se eliminar??n. ??Quiere continuar?';es_CO = 'Los t??rminos de pago se eliminar??n. ??Quiere continuar?';tr = '??deme ??artlar?? silinecek. Devam etmek istiyor musunuz?';it = 'I termini di pagamento saranno cancellati. Continuare?';de = 'Die Zahlungsbedingungen werden verrechnet. M??chten Sie fortfahren?'");
		ShowQueryBox(Notify, QueryText,  QuestionDialogMode.YesNo);
		
	Else
		
		SetEnablePaymentTerms();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SwitchTypeListOfPaymentCalendarOnChange(Item)
	
	PaymentCalendarCount = Object.PaymentCalendar.Count();
	
	If SwitchTypeListOfPaymentCalendar = 0 Then
		
		If PaymentCalendarCount > 1 Then
			
			ClearMessages();
			TextMessage = NStr("en = 'Cannot switch to once-off payment. Several lines for installments are already added.
				|To be able to switch to once-off payment, delete all but one line.'; 
				|ru = '???? ?????????????? ?????????????? ???? ???????????????????????????? ????????????. ?????? ?????????????????? ?????????????????? ?????????? ?????? ???????????? ??????????????.
				|?????????? ?????????????? ???? ???????????????????????????? ????????????, ?????????????? ?????? ????????????, ?????????? ??????????.';
				|pl = 'Nie mo??na prze????czy?? na jednorazow?? p??atno????. Ju?? dodano kilka wierszy dla rat.
				|Aby mie?? mo??liwo???? prze????czenia na jednorazow?? p??atno????, usu?? wszystkie wiersze opr??cz jednego.';
				|es_ES = 'No se puede seleccionar la variante de pago ??nico. Ya se han a??adido varias l??neas para los plazos.
				|Para poder seleccionar la variante de pago ??nico, borre todas las l??neas menos una.';
				|es_CO = 'No se puede seleccionar la variante de pago ??nico. Ya se han a??adido varias l??neas para los plazos.
				|Para poder seleccionar la variante de pago ??nico, borre todas las l??neas menos una.';
				|tr = 'Tek ??demeye ge??ilemiyor. Birden fazla taksit sat??r?? eklendi.
				|Tek ??demeye ge??ebilmek i??in biri haricinde t??m sat??rlar?? silin.';
				|it = 'Impossibile passare a pagamento una tantum. Sono gi?? state aggiunte diverse righe per le rate. 
				|Per poter passare al pagamento una tantum, eliminare tutte le righe tranne una.';
				|de = 'Kann auf einmalige Zahlung nicht umschalten. Mehrere Zeilen f??r Ratenzahlung sind bereits hinzugef??gt.
				|Um auf einmalige Zahlung umschalten zu k??nnen, l??schen Sie alle Zeilen au??er einer.'");
			CommonClientServer.MessageToUser(TextMessage);
			SwitchTypeListOfPaymentCalendar = 1;
			
		ElsIf PaymentCalendarCount = 0 Then
			
			NewLine = Object.PaymentCalendar.Add();
			NewLine.PaymentPercentage = 100;
			
		EndIf;
	EndIf;
	
	SetVisiblePaymentCalendar();
	SetVisiblePaymentMethod();
	
EndProcedure

&AtClient
Procedure PaymentMethodOnChange(Item)
	
	Object.CashAssetType = PaymentMethodCashAssetType(Object.PaymentMethod);
	
	If Object.PaymentMethod <> PredefinedValue("Catalog.PaymentMethods.DirectDebit") Then
		Object.DirectDebitMandate = Undefined;
	EndIf;
	
	SetVisiblePaymentMethod();
	SetPaymentTermsTitle();
	
EndProcedure

&AtClient
Procedure GroupPagesOnCurrentPageChange(Item, CurrentPage)
	
	If CurrentPage = Items.GroupPageGeneratedInvoices Then
		
		ClearMessages();
		If Not CheckFilling() Then
			Item.CurrentPage = Items.GroupPageMain;
			Return;
		EndIf;
		
		SetInvoicesFilters();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure PaymentDateOnChange(Item)
	
	SetPaymentTermsTitle();
	
EndProcedure

#EndRegion

#Region DataTreeFormTableItemsEventHandlers

&AtClient
Procedure DataTreeSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	DataTreeRow = DataTree.FindByID(SelectedRow);
	If DataTreeRow.Level = 1 Then
		ShowValue(Undefined, DataTreeRow.Counterparty);
	ElsIf DataTreeRow.Level = 2 Then
		ShowValue(Undefined, DataTreeRow.Products);
	ElsIf DataTreeRow.Level = 3 Then
		ShowValue(Undefined, DataTreeRow.Invoice);
	EndIf;
	
EndProcedure

&AtClient
Procedure DataTreeProcessOnChange(Item)
	
	DataTreeRow = Items.DataTree.CurrentData;
	
	If Not DataTreeRow.CanBeProcessed Then
		
		DataTreeRow.Process = False;
		
		ErrorMessageText = NStr("en = 'Closing invoice for customer ""%1"" with contract ""%2"" cannot be generated.'; ru = '???? ?????????????? ?????????????? ???????????????????????????? ???????????? ?????? ???????????????????? ""%1"" ?? ?????????????????? ""%2"".';pl = 'Faktura ko??cowa dla nabywcy ""%1"" z kontraktem ""%2"" nie mo??e by?? wygenerowana.';es_ES = 'No se puede generar la factura de cierre para el cliente ""%1"" con el contrato ""%2"".';es_CO = 'No se puede generar la factura de cierre para el cliente ""%1"" con el contrato ""%2"".';tr = '""%2"" s??zle??meli ""%1"" m????terisi i??in kapan???? faturas?? olu??turulamad??.';it = 'La fattura di chiusura per il cliente ""%1"" con contratto ""%2"" non pu?? essere generata.';de = 'Abschlussrechnung f??r den Kunde ""%1"" mit dem Vertrag ""%2"" kann nicht generiert werden.'");
		
		If DataTreeRow.DeliveryStartDateError
			Or DataTreeRow.DeliveryEndDateError Then
			ErrorMessageText = ErrorMessageText + Chars.CR + " "
				+ NStr("en = 'The processed Sales invoices and Actual sales volume documents have delivery periods that do not fully fall within the selected delivery period.
					|To be able to generate Closing invoices, in the ""Sales invoices and Actual sales volume documents"" section, select the delivery period that covers the delivery periods of the processed documents.'; 
					|ru = '???????????????????????? ?????????????? ???????????????????? ?? ?????????????????? ???????????????????????? ???????????? ???????????? ???????????????? ?????????????? ????????????????, ?????????????? ???? ?????????????????? ???????????????? ?? ?????????????????? ???????????? ????????????????.
					|?????????? ?????????????????? ???????????????????????????? ??????????????, ?? ?????????????? ""?????????????? ???????????????????? ?? ?????????????????? ???????????????????????? ???????????? ????????????"" ???????????????? ???????????? ????????????????, ?????????????? ?????????????????? ?????????????? ???????????????? ???????????????????????? ????????????????????.';
					|pl = 'Przetwarzane dokumenty Faktury sprzeda??y i Rzeczywista wielko???? sprzeda??y maj?? okresy dostawy, kt??re nie mieszcz?? si?? w ca??o??ci w wybranym okresie dostawy.
					|Aby mie?? mo??liwo???? wygenerowania Faktur ko??cowych, w sekcji ""Dokumenty Faktury sprzeda??y i Rzeczywista wielko???? sprzeda??y, wybierz okres dostawy, kt??ry pokrywa okresy dostawy przetwarzanych dokument??w.';
					|es_ES = 'Las facturas de venta procesadas y los documentos sobre el volumen real de ventas tienen periodos de entrega que no corresponden totalmente con el periodo de entrega seleccionado.
					|Para poder generar facturas de cierre, en la secci??n ""Facturas de venta y documentos sobre el volumen real de ventas"", seleccione el per??odo de entrega que cubra los per??odos de entrega de los documentos procesados.';
					|es_CO = 'Las facturas de venta procesadas y los documentos sobre el volumen real de ventas tienen periodos de entrega que no corresponden totalmente con el periodo de entrega seleccionado.
					|Para poder generar facturas de cierre, en la secci??n ""Facturas de venta y documentos sobre el volumen real de ventas"", seleccione el per??odo de entrega que cubra los per??odos de entrega de los documentos procesados.';
					|tr = '????lenen Sat???? faturalar?? ile Ger??ekle??en sat???? hacmi belgelerinin teslimat d??nemleri se??ilen teslimat d??nemiyle tam olarak uyu??muyor.
					|Kapan???? faturalar?? olu??turabilmek i??in, ""Sat???? faturalar?? ve Ger??ekle??en sat???? hacmi belgeleri"" b??l??m??nde, i??lemdeki belgelerin teslimat d??nemlerini kapsayacak bir teslimat d??nemi se??in.';
					|it = 'Le fatture di vendita e documenti di volumi effettivi vendite processati hanno un periodo di consegna che non rientrano completamente nel periodo di consegna selezionato. 
					|Per poter generare Fatture di saldo, selezionare il periodo di consegna che corrisponde al periodo di consegna dei documenti processati nella sezione ""Fatture di vendita e documenti di volumi effettivi vendite"".';
					|de = 'Die bearbeiteten Dokumente Verkaufsrechnungen und Aktuelle Verkaufsmenge enthalten Lieferzeitr??ume die nicht v??llig unter dem ausgew??hlten Lieferzeitraum fallen.
					|Um Abschlussrechnungen generieren zu k??nnen, w??hlen Sie im Abschnitt ""Dokumente Verkaufsrechnungen und Aktuelle Verkaufsmenge"" den Lieferzeitraum aus, den die Lieferzeitr??ume der bearbeiteten Dokumente enth??lt.'");
		EndIf;
		If DataTreeRow.PriceError Then
			ErrorMessageText = ErrorMessageText + Chars.CR + " "
				+ NStr("en = 'The processed Sales invoices include different prices for the same services.
					|To be able to generate Closing invoices, do either of the following:
					|* Correct the prices in the processed documents.
					|* In the ""Sales invoices and Actual sales volume documents"" section, select the delivery period in which the service prices are the same.'; 
					|ru = '?? ???????????????????????? ???????????????? ???????????????????? ?????????????? ???????????? ???????? ???? ???????? ?? ???? ???? ????????????.
					|?????????? ?????????????? ???????????????????????????? ??????????????, ?????????????????? ???????? ???? ?????????????????? ????????????????:
					|* ?????????????????? ???????? ?? ???????????????????????? ????????????????????.
					| *?? ?????????????? ""?????????????? ???????????????????? ?? ?????????????????? ???????????????????????? ???????????? ????????????"" ???????????????? ???????????? ????????????????, ?? ?????????????? ???????? ???? ???????????? ??????????????????.';
					|pl = 'Przetwarzane Faktury sprzeda??y zawieraj?? r????ne ceny na te same us??ugi.
					|Aby mie?? mo??liwo???? wygenerowania Faktur ko??cowych, wykonaj jedn?? z nast??puj??cych czynno??ci:
					|* Skoryguj ceny w przetwarzanych dokumentach.
					|* W sekcji ""Dokumenty Faktury sprzeda??y i Rzeczywista wielko???? sprzeda??y, wybierz okres dostawy, w kt??rym ceny us??ugi s?? takie same.';
					|es_ES = 'Las facturas de venta procesadas incluyen diferentes precios para los mismos servicios.
					|Para poder generar las facturas de cierre, realice una de las siguientes acciones:
					|* Corrija los precios en los documentos procesados.
					|*En la secci??n ""Facturas de venta y documentos sobre el volumen real de ventas"", seleccione el periodo de entrega en el que los precios del servicio son los mismos.';
					|es_CO = 'Las facturas de venta procesadas incluyen diferentes precios para los mismos servicios.
					|Para poder generar las facturas de cierre, realice una de las siguientes acciones:
					|* Corrija los precios en los documentos procesados.
					|*En la secci??n ""Facturas de venta y documentos sobre el volumen real de ventas"", seleccione el periodo de entrega en el que los precios del servicio son los mismos.';
					|tr = '????lenen Sat???? faturalar?? ayn?? hizmetler i??in farkl?? fiyatlar i??eriyor.
					|Kapan???? faturalar?? olu??turabilmek i??in ??u i??lemlerden birini yap??n:
					|* ????lenen belgelerdeki fiyatlar?? d??zeltin.
					|* ""Sat???? faturalar?? ve Ger??ekle??en sat???? hacmi belgeleri"" b??l??m??nde, hizmet fiyatlar??n??n ayn?? oldu??u bir teslimat d??nemi se??in.';
					|it = 'Le fatture di vendita processate includono prezzi diversi per gli stessi servizi. 
					|Per poter generare Fatture di chiusura, eseguire una delle seguenti opzioni: 
					|* Correggere i prezzi nei documenti processati. 
					|* Nella sezione ""Fatture di vendita e documenti di volumi effettivi di vendita"" selezionare il periodo di consegna in cui i prezzi dei servizi sono gli stessi.';
					|de = 'Die bearbeiteten Verkaufsrechnungen enthalten unterschiedliche Preise f??r dieselben Dienstleistungen.
					|Um Abschlussrechnungen generieren zu k??nnen, nehmen Sie eine der folgenden Aktionen vor:
					|* Korrigieren Sie die Preise in der bearbeiteten Dokumenten.
					|* Im Abschnitt ""Dokumente Verkaufsrechnungen und Aktuelle Verkaufsmenge"" w??hlen Sie den Lieferzeitraum aus, wann die Preise f??r Dienstleistungen gleich sind.'");
		EndIf;
		If DataTreeRow.VATRateError Then
			ErrorMessageText = ErrorMessageText + Chars.CR + " "
				+ NStr("en = 'The processed Sales invoices include different tax rates for the same services.
					|To be able to generate Closing invoices, do either of the following:
					|* Correct the tax rates in the processed documents.
					|* In the ""Sales invoices and Actual sales volume documents"" section, select the delivery period in which the tax rates are the same.'; 
					|ru = '?? ???????????????????????? ???????????????? ???????????????????? ?????????????? ???????????? ?????????????????? ???????????? ?????? ?????????? ?? ?????? ???? ??????????.
					|?????????? ?????????????? ???????????????????????????? ??????????????, ?????????????????? ???????? ???? ?????????????????? ????????????????:
					|* ?????????????????? ???????????? ?????????????? ?? ???????????????????????? ????????????????????.
					| * ?? ?????????????? ""?????????????????? ?????????????? ?? ?????????????????? ???????????????????????? ???????????? ????????????"" ???????????????? ???????????? ????????????????, ?? ?????????????? ?????????????????? ???????????? ??????????????????.';
					|pl = 'Przetwarzane Faktury sprzeda??y zawieraj?? r????ne stawki VAT na te same us??ugi.
					|Aby mie?? mo??liwo???? wygenerowania Faktur ko??cowych, wykonaj jedn?? z nast??puj??cych czynno??ci:
					|* Skoryguj stawki VAT w przetwarzanych dokumentach.
					|* W sekcji ""Dokumenty Faktury sprzeda??y i Rzeczywista wielko???? sprzeda??y, wybierz okres dostawy, w kt??rym stawki VAT us??ugi s?? takie same.';
					|es_ES = 'Las facturas de venta procesadas incluyen diferentes tasas de impuesto para los mismos servicios.
					|Para poder generar las facturas de cierre, realice una de las siguientes acciones:
					|* Corrija las tasas de impuesto en los documentos procesados.
					|*En la secci??n ""Facturas de venta y documentos sobre el volumen real de ventas"", seleccione el periodo de entrega en el que las tasas de impuesto son las mismas.';
					|es_CO = 'Las facturas de venta procesadas incluyen diferentes tasas de impuesto para los mismos servicios.
					|Para poder generar las facturas de cierre, realice una de las siguientes acciones:
					|* Corrija las tasas de impuesto en los documentos procesados.
					|*En la secci??n ""Facturas de venta y documentos sobre el volumen real de ventas"", seleccione el periodo de entrega en el que las tasas de impuesto son las mismas.';
					|tr = '????lenen Sat???? faturalar?? ayn?? hizmetler i??in farkl?? vergi oranlar?? i??eriyor.
					|Kapan???? faturalar?? olu??turabilmek i??in ??u i??lemlerden birini yap??n:
					|* ????lenen belgelerdeki vergi oranlar??n?? d??zeltin.
					|* ""Sat???? faturalar?? ve Ger??ekle??en sat???? hacmi belgeleri"" b??l??m??nde, vergi oranlar??n??n ayn?? oldu??u bir teslimat d??nemi se??in.';
					|it = 'Le fatture di vendita processate includono diverse aliquote fiscali per gli stessi servizi. 
					|Per poter generare Fatture di chiusura, eseguire una delle seguenti opzioni: 
					|* Correggere le aliquote fiscali nei documenti processati. 
					|* Nella sezione ""Fatture di vendita e documenti di volumi effettivi di vendita"" selezionare il periodo di consegna in cui le aliquote fiscali sono le stesse.';
					|de = 'Die bearbeiteten Verkaufsrechnungen enthalten unterschiedliche Steuers??tze f??r dieselben Dienstleistungen.
					|Um Abschlussrechnungen generieren zu k??nnen, nehmen Sie eine der folgenden Aktionen vor:
					|* Korrigieren Sie die Steuers??tze in der bearbeiteten Dokumenten.
					|* Im Abschnitt ""Dokumente Verkaufsrechnungen und Aktuelle Verkaufsmenge"" w??hlen Sie den Lieferzeitraum aus, wann die Steuers??tze gleich sind.'");
		EndIf;
		If DataTreeRow.ContractCurrencyError Then
			ErrorMessageText = ErrorMessageText + Chars.CR + " "
				+ NStr("en = 'Cannot generate Closing invoices. The processed Sales invoices include amounts in currencies that differ from the company''s presentation currency.'; ru = '???????????????????? ?????????????? ???????????????????????????? ??????????????. ???????????????????????? ?????????????? ???????????????????? ???????????????? ?????????? ?? ??????????????, ?????????????? ???????????????????? ???? ???????????? ?????????????????????????? ???????????????????? ??????????????????????.';pl = 'Nie mo??na wygenerowa?? Faktur ko??cowych. Przetwarzane Faktury sprzeda??y zawieraj?? warto??ci w walutach, kt??re r????ni?? si?? od waluty prezentacji firmy.';es_ES = 'No se pueden generar facturas de cierre. Las facturas de venta procesadas incluyen importes en monedas que difieren de la moneda de presentaci??n de la empresa.';es_CO = 'No se pueden generar facturas de cierre. Las facturas de venta procesadas incluyen importes en monedas que difieren de la moneda de presentaci??n de la empresa.';tr = 'Kapan???? faturas?? olu??turulam??yor. ????lenen Sat???? faturalar?? i?? yerinin finansal tablo para biriminden farkl?? para birimlerinde tutarlar i??eriyor.';it = 'Impossibile generare Fatture di chiusura. Le Fatture di vendita processate includono l''importo in valute diverse dalla valuta di presentazione dell''azienda.';de = 'Abschlussrechnungen k??nnen nicht generiert werden. Die bearbeiteten Verkaufsrechnungen enthalten Mengen in W??hrungen die sich von der W??hrung f??r die Berichtserstattung der Firma unterscheidet.'");
		EndIf;
		If Not (DataTreeRow.DeliveryStartDateError
			Or DataTreeRow.DeliveryEndDateError
			Or DataTreeRow.PriceError
			Or DataTreeRow.VATRateError
			Or DataTreeRow.ContractCurrencyError) Then
			ErrorMessageText = ErrorMessageText + Chars.CR + " "
				+ NStr("en = 'The amount to invoice is 0. Closing invoices are not generated for this amount.'; ru = '?????????????? ?? ??????????????????????: 0. ???????????????????? ?????????????? ???????????????????????????? ???????????? ?????? ?????????????? ??????????.';pl = 'Warto???? do zafakturowania wynosi 0. Nie wygenerowano faktur ko??cowych dla tej warto??ci.';es_ES = 'El importe a facturar es 0. No se generan facturas de cierre por este importe.';es_CO = 'El importe a facturar es 0. No se generan facturas de cierre por este importe.';tr = 'Faturaland??r??lacak tutar 0. Bu tutar i??in Kapan???? faturas?? olu??turulmaz.';it = 'L''importo da fatturare ?? 0. Le fatture di chiusura non sono generate per questo importo.';de = 'Die Menge f??r Rechnungsstellung ist 0. Abschlussrechnungen sind f??r diese Menge nicht generiert.'");
		EndIf;
		
		ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageText, 
			DataTreeRow.Counterparty, DataTreeRow.Contract);
		
		ShowMessageBox(Undefined, ErrorMessageText);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
EndProcedure

#EndRegion

#Region PaymentCalendarFormTableItemsEventHandlers

&AtClient
Procedure PaymentCalendarOnChange(Item)
	
	SetPaymentTermsTitle();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure FillDataTree(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	FillDataTreeAtServer();
	
	SetRefreshNeeded(False);
	
EndProcedure

&AtClient
Procedure CheckAll(Command)
	
	CheckUncheckAll(True);
	
EndProcedure

&AtClient
Procedure UncheckAll(Command)
	
	CheckUncheckAll(False);
	
EndProcedure

&AtClient
Procedure Generate(Command)
	
	ClearMessages();
	If Not CheckFilling() Then
		Return;
	EndIf;
	
	GenerateAtServer();
	
	NotifyChanged(Type("DocumentRef.SalesInvoice"));
	
EndProcedure

&AtClient
Procedure ExpandAll(Command)
	
	ExpandCollapseAll(0);
	
EndProcedure

&AtClient
Procedure CollapseAll(Command)
	
	ExpandCollapseAll(1);
	
EndProcedure

&AtClient
Procedure Print(Command)
	
	ReportParameters = New Structure;
	
	Filter = New Structure;
	Filter.Insert("Period", New StandardPeriod(Object.StartDate, Object.EndDate));
	Filter.Insert("Date", Object.Date);
	Filter.Insert("Company", Object.Company);
	Filter.Insert("Department", Object.Department);
	Filter.Insert("FilterCounterparties", FilterCounterparties);
	
	ReportParameters.Insert("Filter", Filter);
	ReportParameters.Insert("GenerateOnOpen", True);
	
	OpenForm("Report.ClosingInvoices.ObjectForm", ReportParameters);
	
EndProcedure

&AtClient
Procedure SelectPeriod(Command)
	
	Handler = New NotifyDescription("SelectPeriodCompletion", ThisObject);
	
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = New StandardPeriod(Object.StartDate, Object.EndDate);
	Dialog.Show(Handler);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetCounterpartyChoiceParameters()
	
	NewArray = New Array;
	NewArray.Add(New ChoiceParameter("Filter.Customer", True));
	NewArray.Add(New ChoiceParameter("Filter.DoOperationsByContracts", True));
	NewParameters = New FixedArray(NewArray);
	Items.FilterCounterparties.ChoiceParameters = NewParameters;
	
EndProcedure

&AtClient
Procedure SetRefreshNeeded(Flag)
	
	RefreshNeeded = Flag;
	Items.Generate.Enabled = Not Flag;
	Items.DataTreePrint.Enabled = Not Flag;
	Items.DataTreeCheckAll.Enabled = Not Flag;
	Items.DataTreeUncheckAll.Enabled = Not Flag;
	Items.DataTreeProcess.ReadOnly = Flag;
	
EndProcedure

&AtClient
Procedure CheckUncheckAll(Flag)
	
	For Each DataTableRow In DataTree.GetItems() Do
		If DataTableRow.CanBeProcessed Then
			DataTableRow.Process = Flag;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.Level",
		1,
		DataCompositionComparisonType.Greater);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"DataTreeProcess, DataTreeCounterparty, DataTreeContract");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Visible", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.Level",
		2,
		DataCompositionComparisonType.NotEqual);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance,
		"DataTreeProducts, DataTreeCharacteristic, DataTreeBatch, DataTreeMeasurementUnit");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Visible", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.Level",
		3,
		DataCompositionComparisonType.NotEqual);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "DataTreeInvoice");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Visible", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.Level",
		0,
		DataCompositionComparisonType.Greater);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "DataTreeLevel");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Show", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.DeliveryStartDateError",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"RefreshNeeded",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "DataTreeDeliveryStartDate");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.ErrorNoteText);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.DeliveryEndDateError",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"RefreshNeeded",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "DataTreeDeliveryEndDate");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.ErrorNoteText);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.PriceError",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.Level",
		1,
		DataCompositionComparisonType.Greater);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"RefreshNeeded",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "DataTreePrice");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.ErrorNoteText);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.VATRateError",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.Level",
		1,
		DataCompositionComparisonType.Greater);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"RefreshNeeded",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "DataTreeVATRate");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.ErrorNoteText);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.ContractCurrencyError",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"DataTree.Level",
		1,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"RefreshNeeded",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "DataTreeContract");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.ErrorNoteText);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"RefreshNeeded",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "DataTree");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "TextColor", StyleColors.InaccessibleDataColor);
	
EndProcedure

&AtClient
Procedure ExpandCollapseAll(ShowDetails)
	
	For Each Item In DataTree.GetItems() Do
		ItemID = Item.GetID();
		If ShowDetails = 0 Then
			Items.DataTree.Expand(ItemID, True);
		Else
			Items.DataTree.Collapse(ItemID);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure SelectPeriodCompletion(Period, PeriodParameters) Export
	
	If TypeOf(Period) <> Type("StandardPeriod") Then
		Return;
	EndIf;
	
	If ValueIsFilled(Period.StartDate) And ValueIsFilled(Period.EndDate) And Period.StartDate > Period.EndDate Then
		Period.EndDate = Period.StartDate;
	EndIf;
	
	Object.StartDate = Period.StartDate;
	Object.EndDate = Period.EndDate;
	
	SetRefreshNeeded(True);
	
EndProcedure

&AtClient
Procedure SetInvoicesFilters()
	
	Items.List.Period = New StandardPeriod(BegOfDay(Object.Date), EndOfDay(Object.Date));
	
	DriveClientServer.SetListFilterItem(List, "Company", Object.Company, ValueIsFilled(Object.Company));
	DriveClientServer.SetListFilterItem(List, "Department", Object.Department, ValueIsFilled(Object.Department));
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparties, ValueIsFilled(FilterCounterparties));
	
EndProcedure

&AtServer
Procedure GenerateAtServer()
	
	For Each RowLevel1 In DataTree.GetItems() Do
		
		If Not RowLevel1.Process Then
			Continue;
		EndIf;
		
		FillingData = New Structure;
		
		FillingData.Insert("ClosingInvoiceProcessing", True);
		FillingData.Insert("Company", Object.Company);
		FillingData.Insert("Department", Object.Department);
		FillingData.Insert("Date", Object.Date);
		FillingData.Insert("PresentationCurrency", PresentationCurrency);
		FillingData.Insert("DeliveryStartDate", Object.StartDate);
		FillingData.Insert("DeliveryEndDate", Object.EndDate);
		FillingData.Insert("SetPaymentTerms", Object.SetPaymentTerms);
		FillingData.Insert("PaymentMethod", Object.PaymentMethod);
		FillingData.Insert("PettyCash", Object.PettyCash);
		FillingData.Insert("BankAccount", Object.BankAccount);
		FillingData.Insert("DirectDebitMandate", Object.DirectDebitMandate);
		FillingData.Insert("PaymentCalendar", Object.PaymentCalendar.Unload());
		
		FillingData.Insert("Counterparty", RowLevel1.Counterparty);
		FillingData.Insert("Contract", RowLevel1.Contract);
		FillingData.Insert("Inventory", New Array);
		
		For Each RowLevel2 In RowLevel1.GetItems() Do
			
			If RowLevel2.Quantity = 0 Then
				Continue;
			EndIf;
			
			InventoryData = New Structure;
			InventoryData.Insert("DeliveryStartDate", RowLevel2.DeliveryStartDate);
			InventoryData.Insert("DeliveryEndDate", RowLevel2.DeliveryEndDate);
			InventoryData.Insert("Products", RowLevel2.Products);
			InventoryData.Insert("Characteristic", RowLevel2.Characteristic);
			InventoryData.Insert("Batch", RowLevel2.Batch);
			InventoryData.Insert("MeasurementUnit", RowLevel2.MeasurementUnit);
			InventoryData.Insert("ActualQuantity", RowLevel2.ActualQuantity);
			InventoryData.Insert("InvoicedQuantity", RowLevel2.InvoicedQuantity);
			InventoryData.Insert("Quantity", RowLevel2.Quantity);
			InventoryData.Insert("Price", RowLevel2.Price);
			InventoryData.Insert("VATRate", RowLevel2.VATRate);
			InventoryData.Insert("Invoices", New Array);
			
			For Each RowLevel3 In RowLevel2.GetItems() Do
				
				InvoiceData = New Structure;
				InvoiceData.Insert("Invoice", RowLevel3.Invoice);
				InvoiceData.Insert("Quantity", RowLevel3.InvoicedQuantity);
				InventoryData.Invoices.Add(InvoiceData);
				
			EndDo;
			
			FillingData.Inventory.Add(InventoryData);
			
		EndDo;
		
		SalesDoc = Documents.SalesInvoice.CreateDocument();
		SalesDoc.Fill(FillingData);
		If SalesDoc.CheckFilling() Then
			SalesDoc.Write(DocumentWriteMode.Posting);
		EndIf;
		
	EndDo;
	
	ErrorMessages = GetUserMessages();
	For Each ErrorMessage In ErrorMessages Do
		ErrorMessage.DataKey = Undefined;
	EndDo;
	
	FillDataTreeAtServer();
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	
	PresentationCurrency = DriveServer.GetPresentationCurrency(Object.Company);
	
	ChoiceParameters = New Array;
	ChoiceParameters.Add(New ChoiceParameter("Filter.CashCurrency", PresentationCurrency));
	Items.BankAccount.ChoiceParameters = New FixedArray(ChoiceParameters);
	
	ChoiceParameters = New Array;
	ChoiceParameters.Add(New ChoiceParameter("Filter.CurrencyByDefault", PresentationCurrency));
	Items.PettyCash.ChoiceParameters = New FixedArray(ChoiceParameters);
	
EndProcedure

&AtServer
Procedure SetPaymentTermsTitle()
	
		ObjectForPaymentTermsTitle = New Structure;
		ObjectForPaymentTermsTitle.Insert("Ref", Documents.SalesInvoice.EmptyRef());
		ObjectForPaymentTermsTitle.Insert("PaymentCalendar", Object.PaymentCalendar);
		ObjectForPaymentTermsTitle.Insert("EarlyPaymentDiscounts", New Array);
		ObjectForPaymentTermsTitle.Insert("PaymentMethod", Object.PaymentMethod);
		
		Items.GroupPaymentTerms.Title = PaymentTermsServer.TitleStagesOfPayment(ObjectForPaymentTermsTitle);
	
EndProcedure

&AtClient
Procedure SetEnablePaymentTerms()
	
	Items.GroupPaymentMethod.Enabled = Object.SetPaymentTerms;
	Items.SwitchTypeListOfPaymentCalendar.Enabled = Object.SetPaymentTerms;
	Items.GroupPagesPaymentCalendar.Enabled = Object.SetPaymentTerms;
	
	SetPaymentTermsTitle();
	
EndProcedure

&AtClient
Procedure ClearPaymentCalendarContinue(Answer, Parameters) Export
	
	If Answer = DialogReturnCode.Yes Then
		
		Object.PaymentCalendar.Clear();
		SetEnablePaymentTerms();
		
	ElsIf Answer = DialogReturnCode.No Then
		
		Object.SetPaymentTerms = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetVisiblePaymentMethod()
	
	If Object.CashAssetType = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = True;
	ElsIf Object.CashAssetType = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		Items.BankAccount.Visible = True;
		Items.PettyCash.Visible = False;
	Else
		Items.BankAccount.Visible = False;
		Items.PettyCash.Visible = False;
	EndIf;
	
	If Object.PaymentMethod = PredefinedValue("Catalog.PaymentMethods.DirectDebit") Then
		Items.DirectDebitMandate.Visible = True;
		Items.BankAccount.Visible = True;
		Items.PettyCash.Visible = False;
	Else
		Items.DirectDebitMandate.Visible = False;
	EndIf;
	
EndProcedure

&AtServerNoContext
Function PaymentMethodCashAssetType(PaymentMethod)
	
	Return Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	
EndFunction

&AtClient
Procedure SetVisiblePaymentCalendar()
	
	If SwitchTypeListOfPaymentCalendar Then
		Items.GroupPagesPaymentCalendar.CurrentPage = Items.GroupPageInstallments;
	Else
		Items.GroupPagesPaymentCalendar.CurrentPage = Items.GroupPageOnceOffPayment;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillDataTreeAtServer()
	
	DataParameters = New Structure;
	DataParameters.Insert("StartDate", Object.StartDate);
	DataParameters.Insert("EndDate", Object.EndDate);
	DataParameters.Insert("Company", Object.Company);
	DataParameters.Insert("FilterDepartment", ValueIsFilled(Object.Department));
	DataParameters.Insert("Department", Object.Department);
	DataParameters.Insert("FilterCounterparty", FilterCounterparties.Count() > 0);
	DataParameters.Insert("Counterparties", FilterCounterparties.UnloadValues());
	DataParameters.Insert("Date", Object.Date);
	DataParameters.Insert("DataTree", DataTree);
	
	DataProcessors.ClosingInvoiceProcessing.GetData(DataParameters);
	
EndProcedure

&AtClient
Function PricesFields()
	
	Fields = New Array();
	Fields.Add(Items.DataTreePrice);
	
	Return Fields;
	
EndFunction

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Items.List);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Items.List, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.AttachableCommands

#EndRegion

#EndRegion