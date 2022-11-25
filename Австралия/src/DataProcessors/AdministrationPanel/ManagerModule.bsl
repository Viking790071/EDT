#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function CancellationUncheckForeignExchangeAccounting() Export
	
	MessageText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	Currencies.Ref AS Ref
		|FROM
		|	Catalog.Currencies AS Currencies
		|		LEFT JOIN Catalog.Companies AS Companies
		|		ON Currencies.Ref = Companies.PresentationCurrency
		|			AND (Companies.Ref = VALUE(Catalog.Companies.MainCompany))
		|WHERE
		|	Companies.PresentationCurrency IS NULL");
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		MessageText = NStr(
			"en = 'To disable Foreign currency exchange delete all currencies except Presentation currency.'; ru = 'Для отключения обмена валют удалите все валюты, кроме валюты представления отчетности.';pl = 'Aby wyłączyć funkcję Wymiana walut obcych należy usunąć wszystkie waluty z wyjątkiem waluty prezentacji.';es_ES = 'Para desactivar el cambio de moneda extranjera, elimine todas las monedas excepto la de presentación.';es_CO = 'Para desactivar el cambio de moneda extranjera, elimine todas las monedas excepto la de presentación.';tr = 'Döviz işlemlerini devre dışı bırakmak için finansal tablo para birimi dışındaki tüm para birimlerini silin.';it = 'Per disabilitare lo scambio di Valuta straniera, cancellare tutte le valute tranne la Valuta di presentazione.';de = 'Um Fremdwährungswechsel auszublenden, löschen Sie alle Währungen außer Währung für die Berichtserstattung.'");
		
	EndIf;
	
	Return MessageText;
	
EndFunction

Function CancellationUncheckAccountingBySeveralWarehouses() Export
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	BusinessUnits.Ref
		|FROM
		|	Catalog.BusinessUnits AS BusinessUnits
		|WHERE
		|	BusinessUnits.StructuralUnitType = &StructuralUnitType
		|	AND BusinessUnits.Ref <> &MainWarehouse");
	
	Query.SetParameter("StructuralUnitType", Enums.BusinessUnitsTypes.Warehouse);
	Query.SetParameter("MainWarehouse", Catalogs.BusinessUnits.MainWarehouse);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'You cannot disable ""Multi-warehouse accounting"" once used.'; ru = 'При наличии в системе учетных данных отключение опции ""Учет по нескольким складам"" невозможно.';pl = 'Po użyciu nie można wyłączyć opcji ""Rachunek wielomagazynowy"".';es_ES = 'No se puede desactivar la ""Contabilidad multi-almacén"" una vez utilizado.';es_CO = 'No se puede desactivar la ""Contabilidad multi-almacén"" una vez utilizado.';tr = '""Çoklu ambar muhasebesi"" kullanıldıktan sonra devre dışı bırakılamaz.';it = 'Non potete disabilitare ""La contabilità per più magazzini"" una volta utilizzata.';de = 'Sie können die einmal verwendete ""Lagerverwaltung für mehrere Lagerorte"" nicht mehr deaktivieren.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

Function CancellationUncheckFunctionalOptionAccountingByCells() Export
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryInWarehouses.Company
		|FROM
		|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
		|WHERE
		|	InventoryInWarehouses.Cell <> VALUE(Catalog.Cells.EmptyRef)");
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'You cannot disable ""Storage bins"" once used.'; ru = 'При наличии в системе учетных данных отключение опции ""Складские ячейки"" невозможно.';pl = 'Po użyciu nie można wyłączyć opcji ""Pojemniki do przechowywania"".';es_ES = 'No se puede desactivar ""depósitos de almacenamiento"" una vez utilizado.';es_CO = 'No se puede desactivar ""Recipientes de almacenamiento"" una vez utilizado.';tr = '""Depolar"" kullanıldıktan sonra devre dışı bırakılamaz.';it = 'Non potete disabilitare ""Contenitori di magazzino"" una volta utilizzato.';de = 'Sie können ""Lagerplätze"", die einmal verwendet wurden, nicht mehr deaktivieren.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

Function CancellationUncheckFunctionalOptionAccountingInVariousUOM() Export
	
	ErrorText = "";
	
	SelectionOfUOM = Catalogs.UOM.Select();
	While SelectionOfUOM.Next() Do
		
		RefArray = New Array;
		RefArray.Add(SelectionOfUOM.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			
			ErrorText = NStr("en = 'You cannot disable ""Multiple UOMs"" once used.'; ru = 'При наличии в системе учетных данных отключение опции ""Несколько единиц измерения"" невозможно.';pl = 'Po użyciu nie można wyłączyć opcji ""Kilka j.m."".';es_ES = 'No se puede desactivar ""Múltiple UOMs"" una vez utilizado.';es_CO = 'No se puede desactivar ""Múltiple UOMs"" una vez utilizado.';tr = '""Birden fazla ölçü birimi"" kullanıldıktan sonra devre dışı bırakılamaz.';it = 'Non potete disabilitare ""Più unità di misura"" una volta utilizzate';de = 'Sie können ""Mehrere Maßeinheiten"", die einmal verwendet wurden, nicht mehr deaktivieren.'");
			Break;
			
		EndIf;
		
	EndDo;
	
	Return ErrorText;
	
EndFunction

Function CancellationUncheckFunctionalOptionUseCharacteristics() Export
	
	ErrorText = "";
	
	ListOfRegisters = New ValueList;
	ListOfRegisters.Add("ProductRelease");
	ListOfRegisters.Add("InventoryFlowCalendar");
	ListOfRegisters.Add("EmployeeTasks");
	ListOfRegisters.Add("ProductionOrders");
	ListOfRegisters.Add("SalesOrders");
	ListOfRegisters.Add("PurchaseOrders");
	ListOfRegisters.Add("Purchases");
	ListOfRegisters.Add("InventoryInWarehouses");
	ListOfRegisters.Add("StockTransferredToThirdParties");
	ListOfRegisters.Add("StockReceivedFromThirdParties");
	ListOfRegisters.Add("SalesTarget");
	ListOfRegisters.Add("InventoryDemand");
	ListOfRegisters.Add("Sales");
	ListOfRegisters.Add("Backorders");
	ListOfRegisters.Add("Workload");
	
	AccumulationRegistersCounter = 0;
	Query = New Query;
	For Each AccumulationRegister In ListOfRegisters Do
		
		If Query.Text = "" Then
		
			Query.Text = "SELECT TOP 1 ";
			
		Else 
			
			Query.Text = Query.Text +
			"
			|
			|UNION ALL 
			|
			|SELECT TOP 1 ";
			
		EndIf;
		
		Query.Text = Query.Text + 
		"
		|	AccumulationRegister" + AccumulationRegister.Value + ".Characteristic
		|FROM
		|	AccumulationRegister." + AccumulationRegister.Value + " AS AccumulationRegister" + AccumulationRegister.Value + "
		|WHERE
		|	AccumulationRegister" + AccumulationRegister.Value + ".Characteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)";
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
			
		EndTry;
	EndIf;
	
	Query.Text =
	"SELECT TOP 1
	|	Inventory.Characteristic
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Characteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en = 'You cannot disable ""Product variants"" once used.'; ru = 'Не удается отключить опцию. В программе уже созданы варианты номенклатуры.';pl = 'Po użyciu nie można wyłączyć opcji ""Warianty produktu"".';es_ES = 'No se puede desactivar ""Variantes de producto"" una vez utilizado.';es_CO = 'No se puede desactivar ""Variantes de producto"" una vez utilizado.';tr = '""Ürün varyantları"" kullandıktan sonra devre dışı bırakılamaz.';it = 'Non potete disabilitare ""Varianti di articolo"" una volto usate.';de = 'Sie können die einmal verwendeten ""Produktvarianten"" nicht mehr deaktivieren.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

Function CancellationUncheckFunctionalOptionUseBatches() Export
	
	ErrorText = "";
	
	ListOfRegisters = New ValueList;
	ListOfRegisters.Add("ProductRelease");
	ListOfRegisters.Add("Purchases");
	ListOfRegisters.Add("InventoryInWarehouses");
	ListOfRegisters.Add("StockTransferredToThirdParties");
	ListOfRegisters.Add("StockReceivedFromThirdParties");
	ListOfRegisters.Add("Sales");
	
	AccumulationRegistersCounter = 0;
	Query = New Query;
	For Each AccumulationRegister In ListOfRegisters Do
		
		If Query.Text = "" Then
		
			Query.Text = "SELECT TOP 1 ";
			
		Else 
			
			Query.Text = Query.Text +
			"
			|
			|UNION ALL 
			|
			|SELECT TOP 1 ";
			
		EndIf;
		
		Query.Text = Query.Text + 
		"
		|	AccumulationRegister" + AccumulationRegister.Value + ".Batch
		|FROM
		|	AccumulationRegister." + AccumulationRegister.Value + " AS AccumulationRegister" + AccumulationRegister.Value + "
		|WHERE
		|	AccumulationRegister" + AccumulationRegister.Value + ".Batch <> VALUE(Catalog.ProductsBatches.EmptyRef)";
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
			
		EndTry;
	EndIf;
	
	Query.Text =
	"SELECT TOP 1
	|	Inventory.Batch
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Batch <> VALUE(Catalog.ProductsBatches.EmptyRef)";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en = 'You cannot disable ""Batches"" once used.'; ru = 'При наличии в системе учетных данных отключение опции ""Партии"" невозможно.';pl = 'Po użyciu nie można wyłączyć opcji ""Partie"".';es_ES = 'No se puede desactivar ""Lotes"" una vez utilizado.';es_CO = 'No se puede desactivar ""Lotes"" una vez utilizado.';tr = '""Partiler"" kullandıktan sonra devre dışı bırakılamaz.';it = 'Non potete disabilitare ""Lotti"" una volta utilizzati.';de = 'Sie können ""Chargen"", die einmal verwendet wurden, nicht mehr deaktivieren.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

Function CancellationUncheckUseContractsWithCounterparties() Export
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	TRUE AS VrtField
	|FROM
	|	Catalog.Counterparties AS Counterparties
	|WHERE
	|	Counterparties.DoOperationsByContracts";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Cannot clear the checkbox. Tracking AR/AP details by contracts is already 
						|enabled for counterparties (the Contracts checkbox is selected in their cards).'; 
						|ru = 'Не удалось снять флажок. Отслеживание взаиморасчетов по договорам уже 
						|включено для контрагентов (флажок ""По договорам"" уже установлен в их карточках).';
						|pl = 'Nie można odznaczyć pola wyboru. Śledzenie szczegółów Wn/Ma według kontraktów jest już 
						|włączone dla kontrahentów (pole wyboru jest zaznaczone w tych kartach).';
						|es_ES = 'No se puede desmarcar la casilla de verificación. El rastreo de los detalles de AR/AP por contratos ya está 
						|habilitado para las contrapartes (la casilla de verificación Por contrato está seleccionada en sus tarjetas).';
						|es_CO = 'No se puede desmarcar la casilla de verificación. El rastreo de los detalles de AR/AP por contratos ya está 
						|habilitado para las contrapartes (la casilla de verificación Por contrato está seleccionada en sus tarjetas).';
						|tr = 'Onay kutusu temizlenemiyor. Alacak/Borç ayrıntılarının sözleşmelere göre takibi
						|cari hesaplar için zaten etkin (Cari hesapların kartlarında Sözleşmeler onay kutusu seçili).';
						|it = 'Impossibile deselezionare la casella di controllo. Il tracciamento di dettagli Cred/Deb per contratto è già
						|attivato per le controparti (la casella di controllo Contratti è selezionata nelle loro schede).';
						|de = 'Fehler beim Deaktivieren des Kontrollkästchen. Die Verfolgung von Offenen Posten Debitoren/Kreditoren Details nach Verträgen ist bereits für Geschäftspartner 
						|aktiviert (das Kontrollkästchen Verträge ist in seinen Karten aktiviert).'");
		
	ElsIf Constants.IssueClosingInvoices.Get() Then
		
		ErrorText = NStr("en = 'Cannot clear the check box.
			|The Issue closing invoices check box is selected in Settings > Sales > Closing invoices.
			|Contracts are required for issuing closing invoices.'; 
			|ru = 'Не удается снять флажок.
			|Флажок ""Выставлять заключительные инвойсы"" установлен в меню Настройки > Продажи > Заключительные инвойсы.
			|Для выставления заключительных инвойсов необходимы договоры.';
			|pl = 'Nie można wyczyścić pola wyboru.
			|Pole wyboru Wydanie faktury końcowej jest wybrane w Ustawieniach > Sprzedaż > Faktury końcowe.
			|Kontrakty są wymagane do wydania zamykających faktur.';
			|es_ES = 'No se puede desmarcar la casilla de verificación.
			|La casilla de verificación Emitir facturas de cierre está marcada en Configuraciones > Ventas > Facturas de cierre.
			|Se requieren contratos para emitir facturas de cierre.';
			|es_CO = 'No se puede desmarcar la casilla de verificación.
			|La casilla de verificación Emitir facturas de cierre está marcada en Configuraciones > Ventas > Facturas de cierre.
			|Se requieren contratos para emitir facturas de cierre.';
			|tr = 'Onay kutusu temizlenemiyor.
			|Ayarlar > Satış > Kapanış faturaları bölümünde Kapanış faturaları düzenle onay kutusu seçili.
			|Kapanış faturası düzenlemek için sözleşme gerekli.';
			|it = 'Impossibile deselezionare la casella di controllo. 
			| La casella di controllo Emettere fatture di chiusura è selezionata nelle Impostazioni > Vendite > Fatture di chiusura. 
			|I contratti sono richiesti per l''emissione di fatture di chiusura.';
			|de = 'Kann das Kontrollkästchen nicht deaktivieren.
			|Die Ausgabe von Abschlussrechnungen ist in Einstellungen > Verkäufe > Abschlussrechnungen ausgewählt.
			|Verträge sind für Ausgabe von Abschlussrechnungen erforderlich.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

#EndRegion

#EndIf