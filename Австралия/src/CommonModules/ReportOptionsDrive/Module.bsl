#Region Public

// see ReportOptionsOverridable.CustomizeReportsOptions()
//
Procedure CustomizeReportsOptions(Settings) Export
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesOrdersAnalysis, "Default");
	OptionSettings.Details = NStr("en = 'Availability and supply status of goods ordered by customers'; ru = 'Отчет позволяет проанализировать выполнение Заказов покупателей.';pl = 'Dostępność i status dostawy towarów zamówionych przez nabywców';es_ES = 'Disponibilidad y el estado de suministro de mercancías pedidas por clientes';es_CO = 'Disponibilidad y el estado de suministro de mercancías pedidas por clientes';tr = 'Müşteriler tarafından sipariş edilen malların kullanılabilirliği ve tedarik durumu';it = 'La disponibilità e lo stato di rifornimento della merce ordinata dai clienti';de = 'Verfügbarkeit und Lieferstatus der von Kunden bestellten Waren'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesOrderAnalysis, "Default");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PurchaseOrderAnalysis, "Default");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfAccount, "StatementBrieflyContext");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfAccount, "BalanceContext");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AvailableStock, "AvailableBalanceContext");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.GoodsInTransit, "Default");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "SalesContext");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesOrderPayments, "Default");
	OptionSettings.Details = NStr("en = 'Payment info by sales orders'; ru = 'Отчет позволяет проанализировать оплату заказов покупателей';pl = 'Informacje o płatności według zamówień sprzedaży';es_ES = 'Información de pagos por pedidos de cliente';es_CO = 'Información de pagos por órdenes de ventas';tr = 'Satış siparişlerine göre ödeme bilgisi';it = 'Informazioni di pagamento per ordini cliente';de = 'Zahlungsinformationen nach Kundenaufträgen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PurchaseOrderPayments, "Default");
	OptionSettings.Details = NStr("en = 'Payment info by purchase orders'; ru = 'Отчет позволяет проанализировать оплату заказов поставщикам.';pl = 'Informacje o płatności według zamówień zakupu';es_ES = 'Información de pagos por pedidos';es_CO = 'Información de pagos por pedidos';tr = 'Satın alma siparişlerine göre ödeme bilgisi';it = 'Informazioni di pagamento per ordini di acquisto';de = 'Zahlungsinformationen bei Bestellungen an Lieferanten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SupplyPlanning, "Default");
	OptionSettings.Details = NStr("en = 'Raw materials demand and supply status'; ru = 'Отчет позволяет проанализировать обеспечение потребности в сырье и материалах, необходимых для выполнения работ, оказания услуг, производства продукции.';pl = 'Zapotrzebowanie w surowcach i status zaopatrzenia';es_ES = 'Pedido de materias primas y estado de suministro';es_CO = 'Pedido de materias primas y estado de suministro';tr = 'Hammadde talep ve tedarik durumu';it = 'Fabbisogno di materie prime e stato del rifornimento';de = 'Rohstoffe Nachfrage- und Angebotsstatus'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.BalanceSheet, "Default");
	OptionSettings.Details = NStr("en = 'Balance sheet'; ru = 'Бухгалтерский баланс.';pl = 'Bilans';es_ES = 'Hoja de balance';es_CO = 'Hoja de balance';tr = 'Bilanço';it = 'Stato patrimoniale';de = 'Bilanz'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBudget, "Default");
	OptionSettings.Details = NStr("en = 'The report generates cash flow budget by the specified scenario'; ru = 'Отчет формирует бюджет движения денежных средств по указанному сценарию.';pl = 'Raport generuje budżet przepływów pieniężnych zgodnie ze wskazanym scenariuszem';es_ES = 'El informe genera el presupuesto del flujo de efectivo por el escenario especificado';es_CO = 'El informe genera el presupuesto del flujo de efectivo por el escenario especificado';tr = 'Rapor, belirtilen senaryo tarafından nakit akışı bütçesi oluşturur';it = 'Il report genera bilancio dei flussi di cassa dallo scenario specificato';de = 'Der Bericht generiert das Cashflow-Budget nach dem angegebenen Szenario'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBudget, "Planfact analysis");
	OptionSettings.Details = NStr("en = 'The report generates cash flow budget by the specified scenario'; ru = 'Отчет формирует бюджет движения денежных средств по указанному сценарию.';pl = 'Raport generuje budżet przepływów pieniężnych zgodnie ze wskazanym scenariuszem';es_ES = 'El informe genera el presupuesto del flujo de efectivo por el escenario especificado';es_CO = 'El informe genera el presupuesto del flujo de efectivo por el escenario especificado';tr = 'Rapor, belirtilen senaryo tarafından nakit akışı bütçesi oluşturur';it = 'Il report genera bilancio dei flussi di cassa dallo scenario specificato';de = 'Der Bericht generiert das Cashflow-Budget nach dem angegebenen Szenario'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProfitAndLossBudget, "Default");
	OptionSettings.Details = NStr("en = 'The report generates profit and loss budget by the specified scenario'; ru = 'Отчет формирует бюджет прибылей и убытков по указанному сценарию.';pl = 'Sprawozdanie formuje budżet dochodów i strat zgodnie ze wskazanym scenariuszem';es_ES = 'El informe genera el presupuesto de ganancias y pérdidas por el escenario especificado';es_CO = 'El informe genera el presupuesto de ganancias y pérdidas por el escenario especificado';tr = 'Rapor belirtilen senaryo tarafından kar ve zarar bütçesi oluşturur';it = 'Il report genera profitti e perdite di bilancio dallo scenario specificato';de = 'Der Bericht generiert das Budget für Gewinne und Verluste nach dem angegebenen Szenario'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProfitAndLossBudget, "Planfact analysis");
	OptionSettings.Details = NStr("en = 'The report generates variance analysis of profit and loss budgets by the specified scenario'; ru = 'Отчет формирует план-фактный анализ бюджета прибылей и убытков по указанному сценарию.';pl = 'Raport generuje analizę wariancji budżetów zysków i strat według określonego scenariusza';es_ES = 'El informe genera el análisis de variante de los presupuestos de ganancias y pérdidas por el escenario especificado';es_CO = 'El informe genera el análisis de variante de los presupuestos de ganancias y pérdidas por el escenario especificado';tr = 'Rapor, belirtilen senaryo ile kar ve zarar bütçelerinin varyans analizini üretmektedir.';it = 'Il report genera analisi della varianza dei bilanci di profitti e perdite dallo scenario specificato';de = 'Der Bericht generiert eine Abweichungsanalyse der Gewinn- und Verlustbudgets nach dem angegebenen Szenario'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockValuationBySalePrice, "Default");
	OptionSettings.Details = NStr("en = 'Stock valuation by a sale price'; ru = 'Товары в ценах продажи.';pl = 'Wartość zapasów według ceny sprzedaży';es_ES = 'Valor del stock a precios de venta';es_CO = 'Valor del stock a precios de venta';tr = 'Satış fiyatına göre ambar stok değerlemesi';it = 'Valutazione scorte per prezzo di vendita';de = 'Bestandsbewertung durch einen Verkaufspreis'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfAccount, "Statement");
	OptionSettings.Details = NStr("en = 'Extended opening balance, sales/purchases, payments, extended closing balance of receivables and payables'; ru = 'Отчет отображает динамику взаиморасчетов с покупателями и поставщиками сводно за выбранный период времени.';pl = 'Raport pokazuje tendencje dotyczące zobowiązań płatnych i należnych za określony okres';es_ES = 'Saldo de apertura extendido, ventas/compras, pagos, saldo de cierre extendido de las cuentas a cobrar y a pagar';es_CO = 'Saldo de apertura extendido, ventas/compras, pagos, saldo de cierre extendido de las cuentas a cobrar y a pagar';tr = 'Genişletilmiş başlangıç bakiyesi, satışlar/satın almalar, ödemeler, alacak ve borçların genişletilmiş kapanış bakiyesi';it = 'Bilancio di apertura esteso, acquisti/vendite, pagamenti, Chiusura di bilancio estesa di crediti da ricevere e debiti da pagare.';de = 'Erweiterter Anfangssaldo, Verkäufe / Einkäufe, Zahlungen, erweiterter Abschlusssaldo der Forderungen und Verbindlichkeiten'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfAccount, "Balance");
	OptionSettings.Details = NStr("en = 'Payables and receivables balance'; ru = 'Отчет отображает состояние взаиморасчетов с покупателями и поставщиками сводно за выбранный период времени';pl = 'Raport pokazuje saldo konta zobowiązania do zapłaty za określony czas';es_ES = 'Saldo de las cuentas a pagar y a cobrar';es_CO = 'Saldo de las cuentas a pagar y a cobrar';tr = 'Alacaklar ve borçlar bakiyesi';it = 'Saldo debiti e crediti';de = 'Verbindlichkeiten und Forderungen ausgleichen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfAccount, "Statement in currency");
	OptionSettings.Details = NStr("en = 'Extended opening balance, sales/purchases, payments, extended closing balance of receivables and payables'; ru = 'Отчет отображает динамику взаиморасчетов с покупателями и поставщиками сводно за выбранный период времени.';pl = 'Raport pokazuje tendencje dotyczące zobowiązań płatnych i należnych za określony okres';es_ES = 'Saldo de apertura extendido, ventas/compras, pagos, saldo de cierre extendido de las cuentas a cobrar y a pagar';es_CO = 'Saldo de apertura extendido, ventas/compras, pagos, saldo de cierre extendido de las cuentas a cobrar y a pagar';tr = 'Genişletilmiş başlangıç bakiyesi, satışlar/satın almalar, ödemeler, alacak ve borçların genişletilmiş kapanış bakiyesi';it = 'Bilancio di apertura esteso, acquisti/vendite, pagamenti, Chiusura di bilancio estesa di crediti da ricevere e debiti da pagare.';de = 'Erweiterter Anfangssaldo, Verkäufe / Einkäufe, Zahlungen, erweiterter Abschlusssaldo der Forderungen und Verbindlichkeiten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfAccount, "Balance in currency");
	OptionSettings.Details = NStr("en = 'Payables and receivables balance'; ru = 'Отчет отображает состояние взаиморасчетов с покупателями и поставщиками сводно за выбранный период времени';pl = 'Raport pokazuje saldo konta zobowiązania do zapłaty za określony czas';es_ES = 'Saldo de las cuentas a pagar y a cobrar';es_CO = 'Saldo de las cuentas a pagar y a cobrar';tr = 'Alacaklar ve borçlar bakiyesi';it = 'Saldo debiti e crediti';de = 'Verbindlichkeiten und Forderungen ausgleichen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfAccount, "Statement in currency (briefly)");
	OptionSettings.Details = NStr("en = 'Opening balance, sales/purchases, payments, closing balance of receivables and payables'; ru = 'Отчет отображает динамику взаиморасчетов с покупателями и поставщиками сводно за выбранный период времени в валюте расчетов (кратко).';pl = 'Saldo początkowe sprzedaż/zakup, płatności, saldo końcowe należności i i zobowiązań';es_ES = 'Saldo de apertura, ventas/compras, pagos, saldo de cierre de las cuentas a cobrar y a pagar';es_CO = 'Saldo de apertura, ventas/compras, pagos, saldo de cierre de las cuentas a cobrar y a pagar';tr = 'Açılış bakiyesi, satışlar/satın almalar, ödemeler, alacak ve borçların kapanış bakiyesi';it = 'Apertura di bilancio, acquisti/vendite, pagamenti, chiusura di bilancio di crediti da ricevere e debiti da pagare.';de = 'Anfangssaldo, Verkäufe / Einkäufe, Zahlungen, Abschlusssaldo der Forderungen und Verbindlichkeiten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.VATEntriesReconciliation, "Default");
	OptionSettings.Details = NStr("en = 'VAT entries reconciliation'; ru = 'Сверка проводок НДС';pl = 'Uzgodnienie wpisów VAT';es_ES = 'Conciliación de las entradas de diario del IVA';es_CO = 'Conciliación de las entradas del IVA';tr = 'KDV girişleri mutabakatı';it = 'Riconciliazione di inserimenti IVA';de = 'USt.-Eintragsausgleich'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.VATReturn, "Default");
	OptionSettings.Details = NStr("en = 'Provides information to estimate VAT payment'; ru = 'Содержит информацию для расчета платежа НДС.';pl = 'Zawiera informacje do oszacowania płatności podatku VAT';es_ES = 'Proporciona la información para evaluar el pago del IVA';es_CO = 'Proporciona la información para evaluar el pago del IVA';tr = 'KDV ödemesini tahmin etmek için bilgi sağlar';it = 'Fornisce informazioni per stimare il pagamento dell''IVA';de = 'Enthält Informationen zur Schätzung der USt.-Zahlung'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.FixedAssetDepreciation, "Statement");
	OptionSettings.Details = NStr("en = 'The report provides common data on fixed asset depreciation'; ru = 'В отчете отображаются сводные сведения об амортизации основных средств.';pl = 'Raport pokazuje ogólne dane o amortyzacji środków trwałych ';es_ES = 'El informe proporciona los datos comunes de la depreciación del activo fijo';es_CO = 'El informe proporciona los datos comunes de la depreciación del activo fijo';tr = 'Rapor, sabit kıymet amortismanında genel verileri sağlar';it = 'Il report fornisce dati comuni in materia di ammortamento dei cespiti';de = 'Der Bericht liefert gemeinsame Daten zur Abschreibung auf das Anlagevermögen.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.FixedAssetDepreciation, "Card");
	OptionSettings.Details = NStr("en = 'Inventory card'; ru = 'Инвентарная карточка.';pl = 'Karta inwentarzowa';es_ES = 'Tarjeta del inventario';es_CO = 'Tarjeta del inventario';tr = 'Stok kartı';it = 'Scheda inventario';de = 'Bestandskarte'");
	
	// begin Drive.FullVersion
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProductRelease, "Default");
	OptionSettings.Details = NStr("en = 'The report on work performed, services rendered and products released'; ru = 'Отчет по выполнению работ, оказанию услуг и выпуску продукции.';pl = 'Raport z wykonania pracy, świadczenia usług i wypuszczenia produkcji';es_ES = 'El informe sobre el trabajo realizado, servicios prestados y productos lanzados';es_CO = 'El informe sobre el trabajo realizado, servicios prestados y productos lanzados';tr = 'Yapılan işler, sunulan hizmetler ve piyasaya sürülen ürünler hakkında rapor';it = 'Il report sui lavori eseguiti, servizi resi e articoli rilasciati';de = 'Der Bericht über geleistete Arbeit, erbrachte Dienstleistungen und freigegebene Produkte'");
	// end Drive.FullVersion
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.FixedAssetUsage, "Default");
	OptionSettings.Details = NStr("en = 'The report shows information on fixed asset usage for the specified period of time'; ru = 'В отчете отображаются сведения о выработке основных средств за выбранный период времени.';pl = 'Raport pokazuje dane o zużyciu środków trwałych w określonym okresie czasu';es_ES = 'El informe muestra la información sobre el uso de activos fijos para el período de tiempo especificado';es_CO = 'El informe muestra la información sobre el uso de activos fijos para el período de tiempo especificado';tr = 'Rapor belirli bir dönem için sabit kıymet kullanımı hakkında bilgileri gösterir';it = 'Il report mostra informazioni sullìutilizzo di cespiti per il periodo di tempo specificato';de = 'Der Bericht zeigt Informationen zur Nutzung des Anlagevermögens für den angegebenen Zeitraum an.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.InventoryFlowCalendar, "Default");
	OptionSettings.Details = NStr("en = 'On order and expected products by days'; ru = 'Отчет показывает плановые поступления и отгрузки номенклатуры по заказам в количественном выражении за выбранный период времени.';pl = 'Sprawozdanie odzwierciedla planowane odbiór i wysyłkę produktów według zamówień za określony okres w ujęciu ilościowym';es_ES = 'Del pedido y los productos esperados por días';es_CO = 'Del pedido y los productos esperados por días';tr = 'Sipariş edilen ve beklenen ürünler gün bazında';it = 'Su ordini e articoli attesi per giornata';de = 'Auf Bestellung und voraussichtliche Produkte nach Tagen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AvailableStock, "Default");
	OptionSettings.Details = NStr("en = 'Stock on hand, on orders, and available stock by warehouses'; ru = 'Отчет отображает свободный остаток товара на складах.';pl = 'Na stanie, zarezerwowane i dostępne zapasy według magazynów';es_ES = 'Stock en mano, de pedidos, y stock disponible por almacenes';es_CO = 'Stock en mano, de pedidos, y stock disponible por almacenes';tr = 'Eldeki stok, siparişlerde ve ambarlara göre mevcut stok';it = 'Magazzino a portata di mano, su ordini e stock disponibile da magazzini';de = 'Lagerbestand, auf Bestellungen und verfügbarer Bestand von Lagern'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AvailableStock, "AvailableBalanceByStorageBins");
	OptionSettings.Details = NStr("en = 'Stock on hand, on orders, and available stock by warehouses and storage bins'; ru = 'Товарные запасы в наличии, по заказам, а также свободные остатки товара по складам и складским ячейкам.';pl = 'Na stanie, zarezerwowane i dostępne zapasy według magazynów i komórek magazynowych';es_ES = 'Stock en mano, de pedidos, y stock disponible por almacenes y depósitos de almacenamiento';es_CO = 'Stock en mano, de pedidos, y stock disponible por almacenes y depósitos de almacenamiento';tr = 'Ambarlara ve depolara göre eldeki stok, siparişlerdeki stok, mevcut stok';it = 'Scorte a disposizione, su ordinazione e scorte disponibili per magazzini e contenitori di magazzino';de = 'Lagerbestand, auf Bestellungen und verfügbarer Bestand nach Lagern und Lagerplätzen'");
	OptionSettings.FunctionalOptions.Add("UseStorageBins");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AvailableStock, "AvailableBalanceByBatchNumbers");
	OptionSettings.Details = NStr("en = 'Stock on hand, on orders, and available stock by warehouses and batch numbers'; ru = 'Товары в наличии, в заказах и доступные товары в разрезе складов и партий';pl = 'Na stanie, zarezerwowane i dostępne zapasy według magazynów i numerów partii';es_ES = 'Stock en mano, de pedidos, y stock disponible por almacenes y números de lote';es_CO = 'Stock en mano, de pedidos, y stock disponible por almacenes y números de lote';tr = 'Ambarlara ve parti numaralarına göre eldeki stok, siparişlerdeki stok, mevcut stok';it = 'Stock di magazzino, in ordinazione e scorte disponibili per magazzino e numero di lotto';de = 'Lagerbestand, auf Bestellungen und verfügbarer Bestand nach Lagern und Chargennummern'");
	OptionSettings.FunctionalOptions.Add("UseBatches");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AvailableStock, "AvailableBalanceByExpirationDate");
	OptionSettings.Details = NStr("en = 'Stock on hand, on orders, and available stock by warehouses and expiration dates'; ru = 'Товары в наличии, в заказах и доступные товары в разрезе складов и сроков годности';pl = 'Na stanie, zarezerwowane i dostępne zapasy według magazynów i dat wygaśnięcia';es_ES = 'Stock en mano, de pedidos, y stock disponible por almacenes y fechas de expiración';es_CO = 'Stock en mano, de pedidos, y stock disponible por almacenes y fechas de expiración';tr = 'Ambarlara ve sona erme tarihlerine göre eldeki stok, siparişlerdeki stok, mevcut stok';it = 'Stock di magazzino, in ordinazione e scorte disponibili per magazzino e data di scadenza';de = 'Lagerbestand, auf Bestellungen und verfügbarer Bestand nach Lagern und Ablaufdaten'");
	OptionSettings.FunctionalOptions.Add("UseBatches");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.GoodsInTransit, "Default");
	OptionSettings.Details = NStr("en = 'Goods in transit'; ru = 'Товары в пути';pl = 'Towary w tranzycie';es_ES = 'Mercancías en tránsito';es_CO = 'Mercancías en tránsito';tr = 'Transit mallar';it = 'Merci in transito';de = 'Waren in Transit'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashFlow, "Default");
	OptionSettings.Details = NStr("en = 'Cash flow statement of a company for the specified period'; ru = 'Отчет о движении денежных средств организации за указанный период.';pl = 'Sprawozdanie o ruchu środków pieniężnych organizacji za wskazany okres';es_ES = 'Declaración del flujo de efectivo de una empresa para el período especificado';es_CO = 'Declaración del flujo de efectivo de una empresa para el período especificado';tr = 'Belirtilen süre için bir iş yerinin nakit akış tablosu';it = 'Rendiconto finanziario di una società per il periodo indicato';de = 'Cashflow--Auszug einer Firma für den angegebenen Zeitraum'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBalance, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, inflow, outflow, and closing balance by cash accounts'; ru = 'Начальный остаток, приходы, расходы, и конечный остаток по кассовым счетам.';pl = 'Saldo początkowe, przychód, rozchód i saldo końcowe według kas';es_ES = 'Saldo inicial, ingreso, salida y saldo final por cuentas de efectivo';es_CO = 'Saldo inicial, ingreso, salida y saldo final por cuentas de efectivo';tr = 'Kasa hesaplarına göre açılış bakiyesi, giriş, çıkış ve kapanış bakiyesi';it = 'Bilancio di apertura, flusso in ingresso, flusso in ucita, e bilancio di chiusura per conti di cassa';de = 'Anfangssaldo, Mittelzufluss, -abfluss und Abschlusssaldo nach Liquiditätskonten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBalance, "Balance");
	OptionSettings.Details = NStr("en = 'Cash balance by cash accounts'; ru = 'Денежные средства по кассам';pl = 'Środki pieniężne-gotówka za pomocą kas';es_ES = 'Saldo en efectivo por cuentas de efectivo';es_CO = 'Saldo en efectivo por cuentas de efectivo';tr = 'Kasa hesaplarına göre nakit bakiyesi';it = 'Saldo di cassa per conti di cassa';de = 'Kassenbestand nach Liquiditätskonten'");
	OptionSettings.VisibleByDefault	= False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBalance, "Movements analysis");
	OptionSettings.Details = NStr("en = 'Inflow, outflow, and net cash flow'; ru = 'Приходы, расходы и чистый денежный поток.';pl = 'Przychód, rozchód i przepływ gotówki netto';es_ES = 'Ingreso, salida y flujos de efectivo netos';es_CO = 'Ingreso, salida y flujos de efectivo netos';tr = 'Girdi, çıktı ve net nakit akışı';it = 'Flusso in ingresso, flusso in uscita e flusso netto di cassa';de = 'Mittelzufluss, -abfluss und Netto-Cashflow'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBalance, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Opening balance, inflow, outflow, and closing balance by cash accounts'; ru = 'Начальный остаток, приходы, расходы, и конечный остаток по кассовым счетам.';pl = 'Saldo początkowe, przychód, rozchód i saldo końcowe według kas';es_ES = 'Saldo inicial, ingreso, salida y saldo final por cuentas de efectivo';es_CO = 'Saldo inicial, ingreso, salida y saldo final por cuentas de efectivo';tr = 'Kasa hesaplarına göre açılış bakiyesi, giriş, çıkış ve kapanış bakiyesi';it = 'Bilancio di apertura, flusso in ingresso, flusso in ucita, e bilancio di chiusura per conti di cassa';de = 'Anfangssaldo, Mittelzufluss, -abfluss und Abschlusssaldo nach Liquiditätskonten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBalance, "BalanceInCurrency");
	OptionSettings.Details = NStr("en = 'Cash balance by cash accounts'; ru = 'Денежные средства по кассам';pl = 'Środki pieniężne-gotówka za pomocą kas';es_ES = 'Saldo en efectivo por cuentas de efectivo';es_CO = 'Saldo en efectivo por cuentas de efectivo';tr = 'Kasa hesaplarına göre nakit bakiyesi';it = 'Saldo di cassa per conti di cassa';de = 'Kassenbestand nach Liquiditätskonten'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBalance, "Analysis of movements in currency");
	OptionSettings.Details = NStr("en = 'Inflow, outflow, and net cash flow'; ru = 'Приходы, расходы и чистый денежный поток.';pl = 'Przychód, rozchód i przepływ gotówki netto';es_ES = 'Ingreso, salida y flujos de efectivo netos';es_CO = 'Ingreso, salida y flujos de efectivo netos';tr = 'Girdi, çıktı ve net nakit akışı';it = 'Flusso in ingresso, flusso in uscita e flusso netto di cassa';de = 'Mittelzufluss, -abfluss und Netto-Cashflow'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBalance, "CashReceiptsDynamics");
	OptionSettings.Details = NStr("en = 'Cash inflow trend by cash flow items and days, displayed as a chart'; ru = 'Динамика поступлений средств по статьям ДДС и дням, в виде диаграммы';pl = 'Trend przychodu środków pieniężnych według pozycji przepływów pieniężnych i dni, wyświetlany w formie wykresu';es_ES = 'Tendencia de flujo de fondos por elementos del flujo de caja y días, se muestra como un diagrama';es_CO = 'Tendencia de ingreso de efectivo por elementos de flujo de efectivo y días, se muestra como un diagrama';tr = 'Grafik olarak gösterilen nakit akış kalemlerine ve günlerine göre nakit giriş eğilimi';it = 'Dinamica flusso di cassa in entrata per voci flusso di cassa e giorni, mostrati come un grafico';de = 'Entwicklung der Geldzuflüsse nach Cashflow-Posten und Tagen, dargestellt als Diagramm'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBalance, "CashExpenseDynamics");
	OptionSettings.Details = NStr("en = 'Cash outflow trend by cash flow items and days, displayed as a chart'; ru = 'Динамика расходования средств по статьям ДДС и дням, в виде диаграммы';pl = 'Trend rozchodów środków pieniężnych według pozycji przepływów pieniężnych i dni, wyświetlany jako wykres';es_ES = 'Tendencia de salida de caja por elementos del flujo de caja y días, se muestra como un diagrama';es_CO = 'Tendencia de salida de efectivo por elementos de flujo de efectivo y días, se muestra como un diagrama';tr = 'Grafik olarak gösterilen nakit akış kalemlerine ve günlerine göre nakit çıkış eğilimi';it = 'Flusso di cassa in uscita trend per voci flusso di cassa e giorni, mostrati come un grafico';de = 'Entwicklung des Mittelabflusses nach Cashflow-Posten und Tagen, dargestellt als Diagramm'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashRegisterStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, sales, withdrawal, and closing balance in cash registers'; ru = 'Отчет отображает движения денежных средств в кассах ККМ за выбранный период времени.';pl = 'Sprawozdanie odzwierciedla przepływy pieniężne w kasach fiskalnych w ciągu wybranego okresu czasu';es_ES = 'Saldo de apertura, ventas, retiro y saldo de cierre en cajas registradoras';es_CO = 'Saldo de apertura, ventas, retiro y saldo de cierre en cajas registradoras';tr = 'Yazar kasa açılış bakiyesi, satış, para çekme ve kapanış bakiyesi';it = 'Saldo di apertura, di vendita, recesso e saldo finale registratori di cassa';de = 'Anfangssaldo, Verkäufe, Auszahlung und Abschlusssaldo in Kassen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashRegisterStatement, "Balance");
	OptionSettings.Details = NStr("en = 'Cash amount in cash registers'; ru = 'Отчет выводит остатки денежных средств в кассах ККМ на указанную дату';pl = 'Kwota gotówki w kasach fiskalnych';es_ES = 'Importe en efectivo en las cajas registradoras';es_CO = 'Importe en efectivo en las cajas registradoras';tr = 'Yazar kasalardaki nakit tutarı';it = 'Saldo di cassa nei registratori di cassa';de = 'Barbetrag in Kassen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashRegisterStatement, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Opening balance, sales, withdrawal, and closing balance in cash registers'; ru = 'Отчет отображает движения денежных средств в кассах ККМ за выбранный период времени.';pl = 'Sprawozdanie odzwierciedla przepływy pieniężne w kasach fiskalnych w ciągu wybranego okresu czasu';es_ES = 'Saldo de apertura, ventas, retiro y saldo de cierre en cajas registradoras';es_CO = 'Saldo de apertura, ventas, retiro y saldo de cierre en cajas registradoras';tr = 'Yazar kasa açılış bakiyesi, satış, para çekme ve kapanış bakiyesi';it = 'Saldo di apertura, di vendita, recesso e saldo finale registratori di cassa';de = 'Anfangssaldo, Verkäufe, Auszahlung und Abschlusssaldo in Kassen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashFlowVarianceAnalysis, "Default");
	OptionSettings.Details = NStr("en = 'Cash flow budget by cash flow items'; ru = 'Бюджет движения денежных средств по статьям ДДС.';pl = 'Budżet przepływów pieniężnych według pozycji przepływów pieniężnych';es_ES = 'El presupuesto del movimiento de efectivo por elementos de flujo de caja';es_CO = 'Presupuesto de flujo de efectivo por elementos de flujo de caja';tr = 'Nakit akışı öğelerine göre nakit akışı bütçesi';it = 'Budget flusso di cassa per voci del flusso di cassa';de = 'Cashflow-Budget nach Cashflow-Posten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashFlowVarianceAnalysis, "InCurrency");
	OptionSettings.Details = NStr("en = 'Cash flow budget by cash flow items'; ru = 'Бюджет движения денежных средств по статьям ДДС.';pl = 'Budżet przepływów pieniężnych według pozycji przepływów pieniężnych';es_ES = 'El presupuesto del movimiento de efectivo por elementos de flujo de caja';es_CO = 'Presupuesto de flujo de efectivo por elementos de flujo de caja';tr = 'Nakit akışı öğelerine göre nakit akışı bütçesi';it = 'Budget flusso di cassa per voci del flusso di cassa';de = 'Cashflow-Budget nach Cashflow-Posten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashFlowVarianceAnalysis, "Planfact analysis");
	OptionSettings.Details = NStr("en = 'Cash flow variance by cash flow items'; ru = 'Отклонения ДДС по статьям ДДС.';pl = 'Zróżnicowanie przepływów pieniężnych o pozycje przepływów pieniężnych';es_ES = 'Variación de flujo de caja por elementos del flujo de caja';es_CO = 'Variación de flujo de caja por elementos de flujo de caja';tr = 'Nakit akışı öğelerine göre nakit akışı farkı';it = 'Variazione del flusso di cassa per voci flusso di cassa';de = 'Cashflow-Abweichung nach Cashflow-Posten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashFlowVarianceAnalysis, "Planfact analysis (cur.)");
	OptionSettings.Details = NStr("en = 'Cash flow variance by cash flow items'; ru = 'Отклонения ДДС по статьям ДДС.';pl = 'Zróżnicowanie przepływów pieniężnych o pozycje przepływów pieniężnych';es_ES = 'Variación de flujo de caja por elementos del flujo de caja';es_CO = 'Variación de flujo de caja por elementos de flujo de caja';tr = 'Nakit akışı öğelerine göre nakit akışı farkı';it = 'Variazione del flusso di cassa per voci flusso di cassa';de = 'Cashflow-Abweichung nach Cashflow-Posten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.BankCharges, "BankCharges");
	OptionSettings.Details = NStr("en = 'Bank charges'; ru = 'Банковская комиссия.';pl = 'Opłaty bankowe';es_ES = 'Gastos bancarios';es_CO = 'Gastos bancarios';tr = 'Banka masrafları';it = 'Commissioni bancarie';de = 'Bankgebühren'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CashBalanceForecast, "Default");
	OptionSettings.Details = NStr("en = 'Expected cash balance in a selected currency based on payment terms and cash planning documents'; ru = 'Ожидаемый остаток наличности в указанной валюте на основе условий оплаты и документов планирования денежных средств.';pl = 'Oczekiwane saldo gotówkowe w wybranej walucie na podstawie warunków płatności i dokumentów planistycznych środków pieniężnych';es_ES = 'El saldo de caja estimado en la moneda seleccionada que se basa en las condiciones de pago y los documentos de caja planificados';es_CO = 'El saldo de caja estimado en la moneda seleccionada que se basa en las condiciones de pago y los documentos de caja planificados';tr = 'Ödeme şartlarına ve nakit planlama belgelerine bağlı, seçilen para biriminde beklenen nakit bakiyesi';it = 'Saldo di cassa atteso in una valuta seleziona in base ai termini di pagamento e ai documento di pianificazione cassa';de = 'Erwarteter Kassenbestand in einer ausgewählten Währung basierend auf Zahlungsbedingungen und Kassenplanbelegen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.IncomeAndExpenses, "Statement");
	OptionSettings.Details = NStr("en = 'Income and expenses'; ru = 'Доходы и расходы';pl = 'Dochody i rozchody';es_ES = 'Ingresos y gastos';es_CO = 'Ingresos y gastos';tr = 'Gelir ve giderler';it = 'Entrate e uscite';de = 'Einnahme und Ausgaben'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.IncomeAndExpenses, "IncomeAndExpensesByOrders");
	OptionSettings.Details = NStr("en = 'Income and expenses by sales orders'; ru = 'Доходы и расходы по заказам покупателей';pl = 'Dochody i rozchody według zamówień sprzedaży';es_ES = 'Ingresos y gastos por pedidos de cliente';es_CO = 'Ingresos y gastos por pedidos';tr = 'Satış siparişlerine göre gelir ve giderler';it = 'Entrate e uscite per ordine cliente';de = 'Einnahme und Ausgaben nach Kundenaufträgen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.IncomeAndExpenses, "IncomeAndExpensesDynamics");
	OptionSettings.Details = NStr("en = 'Income and expenses by months displayed as a chart'; ru = 'Доходы и расходы по месяцам в виде диаграммы';pl = 'Dochody i dochody według miesięcy wyświetlane jako wykres';es_ES = 'Ingresos y gastos por meses mostrados como diagrama';es_CO = 'Ingresos y gastos por meses mostrados como diagrama';tr = 'Grafik olarak gösterilen aylara göre gelir ve giderler';it = 'Entrate e uscite per mesi mostrati come un grafico';de = 'Einnahme und Ausgaben nach Monaten als Grafik dargestellt'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.IncomeAndExpensesByCashMethod, "Default");
	OptionSettings.Details = NStr("en = 'Income and expenses'; ru = 'Доходы и расходы';pl = 'Dochody i rozchody';es_ES = 'Ingresos y gastos';es_CO = 'Ingresos y gastos';tr = 'Gelir ve giderler';it = 'Entrate e uscite';de = 'Einnahme und Ausgaben'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.IncomeAndExpensesByCashMethod, "IncomeAndExpensesDynamics");
	OptionSettings.Details = NStr("en = 'Income and expenses by months displayed as a chart'; ru = 'Доходы и расходы по месяцам в виде диаграммы';pl = 'Dochody i dochody według miesięcy wyświetlane jako wykres';es_ES = 'Ingresos y gastos por meses mostrados como diagrama';es_CO = 'Ingresos y gastos por meses mostrados como diagrama';tr = 'Grafik olarak gösterilen aylara göre gelir ve giderler';it = 'Entrate e uscite per mesi mostrati come un grafico';de = 'Einnahme und Ausgaben nach Monaten als Grafik dargestellt'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.IncomeAndExpensesBudget, "Statement");
	OptionSettings.Details = NStr("en = 'The report provides forecast data on income and expenses (by shipment)'; ru = 'Отчет содержит прогнозные данные о доходах и расходах (по отгрузке).';pl = 'Sprawozdanie zawiera dane prognostyczne o dochodach i wydatkach (według wysyłki)';es_ES = 'El informe proporciona los datos del pronóstico sobre los ingresos y los gastos (por envío)';es_CO = 'El informe proporciona los datos del pronóstico sobre los ingresos y los gastos (por envío)';tr = 'Rapor gelir ve giderler hakkında tahmin verileri sağlar (gönderiye göre)';it = 'Il report fornisce dati previsionali sulle entrate e sullle uscite (per spedizione)';de = 'Der Bericht liefert Prognosedaten zu Einnahmen und Ausgaben (nach Lieferung)'");
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		OptionSettings.SearchSettings.FieldDescriptions = NStr("en = 'Business line
															|Income and expense item
															|Income
															|Expense
															|Profit (Loss)
															|Currency'; 
															|ru = 'Направление деятельности
															|Статья доходов и расходов
															|Доход
															|Расход
															|Прибыль (убыток)
															|Валюта';
															|pl = 'Rodzaj działalności
															|Pozycja dochodów i rozchodów
															|Dochody
															|Rozchody
															|Zysk (Strata)
															|Waluta';
															|es_ES = 'Línea de negocio
															|Artículos de ingresos y gastos
															|Ingresos
															|Gastos
															|Lucro (Pérdida)
															|Moneda';
															|es_CO = 'Línea de negocio
															|Artículos de ingresos y gastos
															|Ingresos
															|Gastos
															|Lucro (Pérdida)
															|Moneda';
															|tr = 'İş kolu
															|Gelir ve gider kalemi
															|Gelir
															|Gider
															|Kar (Zarar)
															|Para birimi';
															|it = 'Linea aziendale
															|Voce di entrata e uscita
															|Entrata
															|Uscita
															|Profitto (Perdita)
															|Valuta';
															|de = 'Geschäftsbereich
															|Position von Einnahme und Ausgaben
															|Einnahme
															|Ausgaben
															|Gewinn(Verlust)
															|Währung'");
	EndIf;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.IncomeAndExpensesBudget, "Planfact analysis");
	OptionSettings.Details = NStr("en = 'The report provides variance analysis of income and expenses (by shipment)'; ru = 'Отчет содержит план-фактный анализ доходов и расходов (по отгрузке).';pl = 'Sprawozdanie zawiera analizę wariancji dochodów i kosztów (według wysyłki)';es_ES = 'El informe proporciona el análisis de la varianza de los ingresos y los gastos (por envío)';es_CO = 'El informe proporciona el análisis de la varianza de los ingresos y los gastos (por envío)';tr = 'Rapor gelir ve giderlerin sapma analizini sağlar (gönderiye göre)';it = 'Il report fornisce un''analisi della variazioni di entrate e di uscite (per spedizione)';de = 'Der Bericht liefert eine Abweichungsanalyse von Einnahmen und Ausgaben (nach Lieferung)'");
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		OptionSettings.SearchSettings.FieldDescriptions = NStr("en = 'Business line
															|Income and expense item
															|Income
															|Income (actual)
															|Income (variance)
															|Income (percent)
															|Expense
															|Expense (actual)
															|Expense (variance)
															|Expense (percent)
															|Profit (Loss)
															|Profit (loss) (fact)
															|Profit (loss) (variance)
															|Profit (loss) (percent)
															|Currency'; 
															|ru = 'Направление деятельности
															|Статья доходов и расходов
															|Доход
															|Доход (факт)
															|Доход (отклонение)
															|Доход (процент)
															|Расход
															|Расход (факт)
															|Расход (отклонение)
															|Расход (процент)
															|Прибыль (убыток)
															|Прибыль (убыток) (факт)
															|Прибыль (убыток) (отклонение)
															|Прибыль (убыток) (процент)
															|Валюта';
															|pl = 'Rodzaj działalności
															|Pozycja dochodów i rozchodów
															|Dochody
															|Dochody (rzeczywiste)
															|Dochody (odchylenie)
															|Dochody (procent)
															|Rozchody
															|Rozchody (rzeczywiste)
															|Rozchody (odchylenie)
															|Rozchody (procent)
															|Zysk (Strata)
															|Zysk (strata) (faktyczny)
															|Zysk (strata) (odchylenie)
															|Zysk (strata) (procent)
															|Waluta';
															|es_ES = 'Línea de negocio
															|Artículo de ingresos y gastos
															|Ingresos
															|Ingresos (actuales)
															|Ingresos (varianza)
															|Ingresos (por ciento)
															|Gastos
															|Gastos (actuales)
															|Gastos (varianza)
															|Gastos (por ciento)
															|Lucro (Pérdida)
															|Lucro (pérdida) (hecho)
															|Lucro (pérdida) (varianza)
															|Lucro (pérdida) (por ciento)
															|Moneda';
															|es_CO = 'Línea de negocio
															|Artículo de ingresos y gastos
															|Ingresos
															|Ingresos (actuales)
															|Ingresos (varianza)
															|Ingresos (por ciento)
															|Gastos
															|Gastos (actuales)
															|Gastos (varianza)
															|Gastos (por ciento)
															|Lucro (Pérdida)
															|Lucro (pérdida) (hecho)
															|Lucro (pérdida) (varianza)
															|Lucro (pérdida) (por ciento)
															|Moneda';
															|tr = 'İş kolu
															|Gelir ve gider kalemi
															|Gelir
															|Gelir (gerçekleşen)
															|Gelir (fark)
															|Gelir (yüzde)
															|Gider
															|Gider (gerçekleşen)
															|Gider (fark)
															|Gider (yüzde)
															|Kar (Zarar)
															|Kar (Zarar) (gerçek)
															|Kar (Zarar) (fark)
															|Kar (Zarar) (yüzde)
															|Para birimi';
															|it = 'Linea aziendale
															|Voce di entrata e uscita
															|Entrata
															|Uscita (effettiva)
															|Entrata (variazione)
															|Entrata (percentuale)
															|Uscita
															|Uscita (effettiva)
															|Uscita (variazione)
															|Uscita (percentuale)
															|Profitto (Perdita)
															|Profitto (perdita) (effettiva)
															|Profitto (perdita) (variazione)
															|Profitto (perdita) (percentuale)
															|Valuta';
															|de = 'Geschäftsbereich
															|Position von Einnahme und Ausgaben
															|Einnahme
															|Einnahme(aktuell)
															|Einnahme(Abweichung)
															|Einnahme (Prozent)
															|Ausgaben
															|Ausgaben (aktuell)
															|Ausgaben (Abweichung)
															|Ausgaben (Prozent)
															|Gewinn (Verlust)
															|Gewinn (Verlust) (aktuell)
															|Gewinn (Verlust) (Abweichung)
															|Gewinn (Verlust) (Prozent)
															|Währung'");
	EndIf;
	
	// begin Drive.FullVersion
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.WorkloadVariance, "Default");
	OptionSettings.Details = NStr("en = 'The report shows scheduled and completed work orders.'; ru = 'Отчет содержит запланированные и выполненные заказы-наряды.';pl = 'Raport pokazuje zaplanowane i wykonane zlecenia pracy.';es_ES = 'El informe muestra los órdenes de trabajos programados y finalizados.';es_CO = 'El informe muestra los órdenes de trabajos programados y finalizados.';tr = 'Rapor planlı ve tamamlanmış iş emirlerini gösterir.';it = 'Il report mostra le commesse pianificate e completate.';de = 'Der Bericht zeigt geplante und abgeschlossene Arbeitsaufträge.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.WorkloadVariance, "ReportToCustomer");
	OptionSettings.Details = NStr("en = 'The report provides information about performed work orders to the customer'; ru = 'Отчет заказчику о выполненных заказах-нарядах.';pl = 'Raport jest przeznaczony do udzielenia nabywcy informacji o wykonanych zleceniach pracy';es_ES = 'El informe proporciona la información sobre los órdenes de trabajos realizados para el cliente';es_CO = 'El informe proporciona la información sobre los órdenes de trabajos realizados para el cliente';tr = 'Rapor müşteriye yapılan iş emirleri hakkında bilgi sağlar';it = 'Il report fornisce informazioni sulle commesse svolte per il cliente';de = 'Der Bericht liefert Informationen über durchgeführte Arbeitsaufträge an den Kunden'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProductionOrderStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, ordered, produced, and closing balance'; ru = 'Отчет отображает динамику работы с заказами за выбранный период.';pl = 'Saldo początkowe, zamówiono, wyprodukowano i saldo końcowe';es_ES = 'Saldo de apertura, pedido, fabricado y saldo de cierre';es_CO = 'Saldo de apertura, pedido, fabricado y saldo de cierre';tr = 'Açılış bakiyesi, sipariş edilen, üretilen ve kapanış bakiyesi';it = 'Saldo di apertura, ordinato, prodotti, e la chiusura di equilibrio';de = 'Anfangssaldo, bestellt, produziert und Abschlusssaldo'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProductionOrderStatement, "Balance");
	OptionSettings.Details = NStr("en = 'The report shows the order statuses within the specified period.'; ru = 'В отчете отображаются статусы заказов за указанный период.';pl = 'Raport pokazuje statusy zamówienia w określonym określonym.';es_ES = 'El informe muestra los estados del pedido dentro del período especificado.';es_CO = 'El informe muestra los estados del pedido dentro del período especificado.';tr = 'Rapor, belirtilen dönem içindeki sipariş/emir durumlarını gösteriyor.';it = 'Il report mostra gli stati dell''ordine entro il periodo specificato.';de = 'Der Bericht zeigt die Auftragsstatus innerhalb des angegebenen Zeitraums an.'");
	OptionSettings.VisibleByDefault = False;
	// end Drive.FullVersion
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesOrdersStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, ordered, shipped, and remaining'; ru = 'Отчет отображает динамику работы с заказами за выбранный период';pl = 'Sprawozdanie odzwierciedla dynamikę pracy z zamówieniami za wybrany okres';es_ES = 'Saldo de apertura, pedido, enviado y restante';es_CO = 'Saldo de apertura, pedido, enviado y restante';tr = 'Açılış bakiyesi, sipariş edilen, sevk edilen ve kalan';it = 'Saldo di apertura, ordinato, spedito, e restante';de = 'Anfangssaldo, bestellt, versendet und verbleibend'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesOrdersStatement, "Balance");
	OptionSettings.Details = NStr("en = 'Goods to dispatch'; ru = 'Отчет отображает состояние заказов на указанную дату';pl = 'Towary do wysyłki';es_ES = 'Mercancías para enviar';es_CO = 'Mercancías para enviar';tr = 'Sevk edilecek mallar';it = 'Merce per la spedizione';de = 'Waren zu versenden'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.OrdersByFullfillment, "PurchaseOrdersByFulfillment");
	OptionSettings.Details = NStr("en = 'Shows Purchase orders related to Sales orders by fulfillment method.'; ru = 'Показывает заказы поставщикам, связанные с заказами покупателей по способу выполнения.';pl = 'Pokazuje Zamówienia zakupu, powiązane z Zamówieniami sprzedaży według sposobu wykonania.';es_ES = 'Muestra las órdenes de compra relacionadas con las órdenes de ventas por el método de cumplimiento.';es_CO = 'Muestra las órdenes de compra relacionadas con las órdenes de ventas por el método de cumplimiento.';tr = 'Yerine getirme yöntemine göre Satış siparişlerine ilişkin Satın alma siparişlerini gösterir.';it = 'Mostra gli Ordini di acquisto relativi agli Ordini cliente per metodo di completamento.';de = 'Zeigt Bestellungen an Lieferanten verbunden mit den Kundenaufträgen nach Erfüllungsmethode an.'");
	OptionSettings.VisibleByDefault = True;
	OptionSettings.FunctionalOptions.Add("UseDropShipping");
	OptionSettings.Placement.Delete(Metadata.Subsystems.Sales.Subsystems.Sales);
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.OrdersByFullfillment, "SalesOrdersByFulfillment");
	OptionSettings.Details = NStr("en = 'Shows Sales orders related to Purchase orders by fulfillment method.'; ru = 'Показывает заказы покупателей, связанные с заказами поставщикам по способу выполнения.';pl = 'Pokazuje Zamówienia sprzedaży powiązane z Zamówieniami zakupu według sposobu wykonania.';es_ES = 'Muestra las órdenes de ventas relacionadas con las órdenes de compra por el método de cumplimiento.';es_CO = 'Muestra las órdenes de ventas relacionadas con las órdenes de compra por el método de cumplimiento.';tr = 'Yerine getirme yöntemine göre Satın alma siparişlerine ilişkin Satış siparişlerini gösterir.';it = 'Mostra gli Ordini cliente relativi agli Ordini di acquisto per metodo di completamento.';de = 'Zeigt Kundenaufträge verbunden mit den Bestellungen an Lieferanten nach Erfüllungsmethode an.'");
	OptionSettings.VisibleByDefault = True;
	OptionSettings.FunctionalOptions.Add("UseDropShipping");
	OptionSettings.Placement.Delete(Metadata.Subsystems.Purchases.Subsystems.Purchases);
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.WorkOrdersStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, ordered, fullfilled, and remaining'; ru = 'Отчет отображает динамику работы с заказами за выбранный период.';pl = 'Saldo początkowe, zamówiono, wykonano i pozostało';es_ES = 'Saldo de apertura, pedido, cumplido y restante';es_CO = 'Saldo de apertura, pedido, cumplido y restante';tr = 'Açılış bakiyesi, sipariş edilen, gerçekleştirilen ve kalan';it = 'Saldo di apertura, ordinati, completati, e rimanenti';de = 'Anfangssaldo, bestellt, erfüllt und verblieben'");
	OptionSettings.VisibleByDefault = True;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.WorkOrdersStatement, "Balance");
	OptionSettings.Details = NStr("en = 'Works to fullfill'; ru = 'Отчет отображает состояние работ на указанную дату.';pl = 'Prace do wykonania';es_ES = 'Trabajos a cumplir';es_CO = 'Trabajos a cumplir';tr = 'Yerine getirilecek işler';it = 'Lavori da compilare';de = 'Zu erfüllende Arbeiten'");
	OptionSettings.VisibleByDefault = True;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PurchaseOrdersStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, ordered, received, and expected'; ru = 'Отчет отображает динамику работы с заказами за выбранный период';pl = 'Sprawozdanie odzwierciedla dynamikę pracy z zamówieniami za wybrany okres';es_ES = 'Saldo de apertura, pedido, recibido y esperado';es_CO = 'Saldo de apertura, pedido, recibido y esperado';tr = 'Açılış bakiyesi, sipariş edilen, teslim alınan ve beklenen';it = 'Saldo di apertura, ordinato, ricevuto, e attese';de = 'Anfangssaldo, bestellt, erhalten und erwartet'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PurchaseOrdersStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, ordered, received, and expected'; ru = 'Отчет отображает динамику работы с заказами за выбранный период';pl = 'Sprawozdanie odzwierciedla dynamikę pracy z zamówieniami za wybrany okres';es_ES = 'Saldo de apertura, pedido, recibido y esperado';es_CO = 'Saldo de apertura, pedido, recibido y esperado';tr = 'Açılış bakiyesi, sipariş edilen, teslim alınan ve beklenen';it = 'Saldo di apertura, ordinato, ricevuto, e attese';de = 'Anfangssaldo, bestellt, erhalten und erwartet'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PurchaseOrdersStatement, "Balance");
	OptionSettings.Details = NStr("en = 'Expected goods'; ru = 'Отчет отображает состояние заказов на указанную дату';pl = 'Sprawozdanie odzwierciedla stan zamówień na wskazaną datę';es_ES = 'Mercancías esperadas';es_CO = 'Mercancías esperadas';tr = 'Beklenen ürünler';it = 'Merci attese';de = 'Erwartete Ware'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.Purchases, "Default");
	OptionSettings.Details = NStr("en = 'Purchases quantity and amount'; ru = 'Отчет предназначен для анализа закупок номенклатуры, совершенных предприятием в течение заданного периода времени.';pl = 'Sprawozdanie służy do analizy produktów zakupionych przez firmę w określonym czasie';es_ES = 'Cantidad de compras y el importe';es_CO = 'Cantidad de compras y el importe';tr = 'Satın alma miktarı ve tutarı';it = 'Quantità e importo degli acquisti';de = 'Käufe Menge und Betrag'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.Purchases, "ZeroInvoice");
	OptionSettings.Details = NStr("en = 'Purchases including zero invoices'; ru = 'Закупки, включая нулевые инвойсы';pl = 'Zakup, w tym faktury zerowe';es_ES = 'Compras que incluyen facturas con importe cero';es_CO = 'Compras que incluyen facturas con importe cero';tr = 'Sıfır bedelli fatura içeren satın almalar';it = 'Acquisti incluse Fattura a zero';de = 'Einkäufe einschließlich Nullrechnungen'");
	OptionSettings.FunctionalOptions.Add("UseZeroInvoicePurchases");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, receipt, consumption, closing balance by products and documents'; ru = 'Начальный остаток, поступление, расход, конечный остаток по номенклатуре и документам.';pl = 'Saldo początkowe, paragon, konsumpcja, saldo końcowe według produktów i dokumentów';es_ES = 'Saldo inicial, recepción, consumo, saldo de cierre por productos y documentos';es_CO = 'Saldo inicial, recepción, consumo, saldo de cierre por productos y documentos';tr = 'Ürün ve belgelere göre açılış bakiyesi, alınan, tüketim, kapanış bakiyesi';it = 'Bilancio di apertura, ricevuta, consumo, bilancio di chiusura per articoli e documenti';de = 'Anfangssaldo, Eingang, Verbrauch, Abschlusssaldo nach Produkten und Dokumenten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockStatement, "StatementByBatchNumbers");
	OptionSettings.Details = NStr("en = 'Opening balance, receipt, consumption, closing balance by products and batch numbers'; ru = 'Начальный остаток, приход, потребление, конечный остаток в разрезе номенклатуры и партий';pl = 'Saldo początkowe, paragon, konsumpcja, saldo końcowe według produktów i numerów partii';es_ES = 'Saldo inicial, recepción, consumo, saldo de cierre por productos y números del lote';es_CO = 'Saldo inicial, recepción, consumo, saldo de cierre por productos y números del lote';tr = 'Ürün ve parti numaralarına göre açılış bakiyesi, alınan, tüketim, kapanış bakiyesi';it = 'Saldo iniziale, ricevuta, consumo, bilancio di chiusura per prodotto e numero di lotto';de = 'Anfangssaldo, Eingang, Verbrauch, Abschlusssaldo nach Produkten und Chargennummern'");
	OptionSettings.FunctionalOptions.Add("UseBatches");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SurplusesAndShortages, "Default");
	OptionSettings.Details = NStr("en = 'The report provides information on surpluses and shortages according to the physical inventory results'; ru = 'Отчет позволяет получить информацию об излишках и недостачах по итогам инвентаризации';pl = 'Raport zawiera informacje o nadwyżkach i niedoborach zgodnie z wynikami spisu z natury';es_ES = 'El informe proporciona la información sobre excesos y faltas según los resultados del inventario físico';es_CO = 'El informe proporciona la información sobre excesos y faltas según los resultados del inventario físico';tr = 'Rapor, fiziksel stok sonuçlarına göre fazlalıklar ve eksiklikler hakkında bilgi verir';it = 'Il report consente di ottenere informazioni su surplus e su deficit di scorte';de = 'Der Bericht enthält Informationen zu Überschüssen und Fehlmengen gemäß den Ergebnissen der physischen Inventur'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockTransferredToThirdParties, "Statement");
	OptionSettings.Details = NStr("en = 'The report provides information about changes of inventory balance received for commission, processing, and safekeeping for the specified period'; ru = 'Отчет позволяет получить информацию об изменении запасов, принятых на комиссию, в переработку и на ответственное хранение за указанный период времени';pl = 'Sprawozdanie pozwala otrzymać informację o zmianie zapasów, przyjętych na komis, do przetwarzania i na odpowiedzialne przechowywanie w ciągu wskazanego okresu czasu';es_ES = 'El informe proporciona la información sobre los cambios del balance del inventario recibido para la comisión, el procesamiento y la custodia para el período especificado';es_CO = 'El informe proporciona la información sobre los cambios del balance del inventario recibido para la comisión, el procesamiento y la custodia para el período especificado';tr = 'Rapor, belirtilen süre için komisyon, işleme ve güvenli saklama için alınan stok bakiyesi değişiklikleri hakkında bilgi verir.';it = 'Il report fornisce informazioni sulle modifiche del livello delle scorte ricevute in conto vendita, la lavorazione conto terzi e la custodia per il periodo specificato';de = 'Der Bericht enthält Informationen zu Änderungen des Bestandes, die zur Provision, Verarbeitung und externe Verwahrung für den angegebenen Zeitraum eingehen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockTransferredToThirdParties, "Balance");
	OptionSettings.Details			= NStr("en = 'The report provides information about inventory balance received for commission, processing, and safekeeping.'; ru = 'Отчет позволяет получить информацию об остатках запасов, принятых на комиссию, в переработку и на ответственное хранение.';pl = 'Sprawozdanie pozwala otrzymać informację o bilansie zapasów, przyjętych na komis, do przetwarzania i na odpowiedzialne przechowywanie';es_ES = 'El informe proporciona la información sobre el balance del inventario recibido para la comisión, el procesamiento y la custodia.';es_CO = 'El informe proporciona la información sobre el balance del inventario recibido para la comisión, el procesamiento y la custodia.';tr = 'Rapor, komisyon, işleme ve güvenli saklama için alınan stok bakiyesi hakkında bilgi verir.';it = 'Il report fornisce informazioni sui saldi delle scorte ricevute in conto vendita, lavorazione in conto terzi e custodia.';de = 'Der Bericht enthält Informationen über den für Provision, Verarbeitung und externe Verwahrung erhaltenen Bestand.'");
	OptionSettings.VisibleByDefault	= False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockReceivedFromThirdParties, "Statement");
	OptionSettings.Details = NStr("en = 'The report provides information about changes of inventory balance received for commission, processing, and safekeeping for the specified period'; ru = 'Отчет позволяет получить информацию об изменении запасов, принятых на комиссию, в переработку и на ответственное хранение за указанный период времени';pl = 'Sprawozdanie pozwala otrzymać informację o zmianie zapasów, przyjętych na komis, do przetwarzania i na odpowiedzialne przechowywanie w ciągu wskazanego okresu czasu';es_ES = 'El informe proporciona la información sobre los cambios del balance del inventario recibido para la comisión, el procesamiento y la custodia para el período especificado';es_CO = 'El informe proporciona la información sobre los cambios del balance del inventario recibido para la comisión, el procesamiento y la custodia para el período especificado';tr = 'Rapor, belirtilen süre için komisyon, işleme ve güvenli saklama için alınan stok bakiyesi değişiklikleri hakkında bilgi verir.';it = 'Il report fornisce informazioni sulle modifiche del livello delle scorte ricevute in conto vendita, la lavorazione conto terzi e la custodia per il periodo specificato';de = 'Der Bericht enthält Informationen zu Änderungen des Bestandes, die zur Provision, Verarbeitung und externe Verwahrung für den angegebenen Zeitraum eingehen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockReceivedFromThirdParties, "Balance");
	OptionSettings.Details			= NStr("en = 'The report provides information about inventory balance received for commission, processing, and safekeeping.'; ru = 'Отчет позволяет получить информацию об остатках запасов, принятых на комиссию, в переработку и на ответственное хранение.';pl = 'Sprawozdanie pozwala otrzymać informację o bilansie zapasów, przyjętych na komis, do przetwarzania i na odpowiedzialne przechowywanie';es_ES = 'El informe proporciona la información sobre el balance del inventario recibido para la comisión, el procesamiento y la custodia.';es_CO = 'El informe proporciona la información sobre el balance del inventario recibido para la comisión, el procesamiento y la custodia.';tr = 'Rapor, komisyon, işleme ve güvenli saklama için alınan stok bakiyesi hakkında bilgi verir.';it = 'Il report fornisce informazioni sui saldi delle scorte ricevute in conto vendita, lavorazione in conto terzi e custodia.';de = 'Der Bericht enthält Informationen über den für Provision, Verarbeitung und externe Verwahrung erhaltenen Bestand.'");
	OptionSettings.VisibleByDefault	= False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.EventCalendar, "Default");
	OptionSettings.Details = NStr("en = 'Planned events'; ru = 'Отчет позволяет получить информацию по событиям, сгруппированным по статусам (просроченные, на сегодня, запланированные).';pl = 'Planowane wydarzenia';es_ES = 'Eventos programados';es_CO = 'Eventos programados';tr = 'Planlanan etkinlikler';it = 'Eventi pianificati';de = 'Geplante Ereignisse'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CounterpartyContactInformation, "CounterpartyContactInformation");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.EarningsAndDeductions, "Default");
	OptionSettings.Details = NStr("en = 'Earnings and deductions by employees and departments'; ru = 'Начисления и удержания по сотрудникам и подразделениям.';pl = 'Zarobki i potrącenia według pracowników i działów';es_ES = 'Ingresos y deducciones por empleados y departamentos';es_CO = 'Ingresos y deducciones por empleados y departamentos';tr = 'Çalışanlar ve bölümlere göre kazançlar ve kesintiler';it = 'Proventi e trattenute per dipendenti e reparti';de = 'Bezüge und Abzüge von Mitarbeitern und Abteilungen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.EarningsAndDeductions, "InCurrency");
	OptionSettings.Details = NStr("en = 'Earnings and deductions by employees and departments'; ru = 'Начисления и удержания по сотрудникам и подразделениям.';pl = 'Zarobki i potrącenia według pracowników i działów';es_ES = 'Ingresos y deducciones por empleados y departamentos';es_CO = 'Ingresos y deducciones por empleados y departamentos';tr = 'Çalışanlar ve bölümlere göre kazançlar ve kesintiler';it = 'Proventi e trattenute per dipendenti e reparti';de = 'Bezüge und Abzüge von Mitarbeitern und Abteilungen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfCost, "Statement");
	OptionSettings.Details = NStr("en = 'The report shows data on changes of direct and indirect costs of the company. The data is shown by departments drilled down by sales orders'; ru = 'Отчет предоставляет информацию об изменениях прямых и косвенных затрат предприятия. Данные представлены в разрезе подразделений с детализацией по заказам покупателей.';pl = 'Raport pokazuje dane o zmianach bezpośrednich i pośrednich kosztów firmy. Dane są wyświetlane według działów z uściśleniem według zamówień sprzedaży';es_ES = 'El informe muestra los datos sobre los cambios de los costes directos e indirectos de la empresa. Los datos se muestran por departamentos clasificados por pedidos de cliente';es_CO = 'El informe muestra los datos sobre los cambios de los costes directos e indirectos de la empresa. Los datos se muestran por departamentos clasificados por órdenes de ventas';tr = 'Rapor, iş yerinin doğrudan ve dolaylı maliyetlerindeki değişikliklere ilişkin verileri göstermektedir. Veriler, satış siparişleri ile açılan bölümler tarafından gösterilir.';it = 'Il report mostra i dati sui cambiamenti di costi diretti e indiretti dell''azienda. I dati sono mostrati per reparto dettagliati per ordine cliente';de = 'Der Bericht zeigt Daten über Änderungen der direkten und indirekten Kosten der Firma. Die Daten werden von Abteilungen gezeigt aufgerissen nach Kundenaufträgen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfCost, "Balance");
	OptionSettings.Details = NStr("en = 'The report shows data on the state of direct and indirect costs of the company. The data is shown by departments drilled down by sales orders'; ru = 'Отчет предоставляет информацию о состоянии прямых и косвенных затрат предприятия. Данные представлены в разрезе подразделений с детализацией по заказам покупателей';pl = 'Sprawozdanie odzwierciedla dane na temat stanu bezpośrednich i pośrednich kosztów firmy. Dane są wyświetlane według działów z uściśleniem według zamówienia sprzedaży';es_ES = 'El informe muestra los datos sobre el estado de los costes directos e indirectos de la empresa. Los datos se muestran por departamentos clasificados por órdenes de ventas';es_CO = 'El informe muestra los datos sobre el estado de los costes directos e indirectos de la empresa. Los datos se muestran por departamentos clasificados por órdenes de ventas';tr = 'Rapor, iş yerinin doğrudan ve dolaylı maliyetlerinin durumunu gösterir. Veriler, satış siparişleri ile açılan bölümler tarafından gösterilir.';it = 'Il report mostra i dati sullo stato di costi diretti e indiretti dell''azienda. I dati sono mostrati per reparto dettagliati per ordine cliente';de = 'Der Bericht zeigt Daten zum Stand der direkten und indirekten Kosten der Firma. Die Daten werden von Abteilungen gezeigt aufgerissen nach Kundenaufträgen'");
	OptionSettings.VisibleByDefault	= False;
	
	// begin Drive.FullVersion
	Report = ReportsOptions.ReportDetails(Settings, Metadata.Reports.RawMaterialsCalculation); 
	// OptionSettings does not exist, the description shall be set for report.
	ReportsOptions.SetOutputModeInReportPanes(Settings, Report, True);
	Report.Details = NStr("en = 'The report provides information on standards and technologies of work and products'; ru = 'Отчет предоставляет информацию о нормативном составе и технологии работ, продукции.';pl = 'Raport udostępnia informację o standardach i technologiach pracy i produkcji';es_ES = 'El informe proporciona la información sobre los estándares y las tecnologías de trabajo y productos';es_CO = 'El informe proporciona la información sobre los estándares y las tecnologías de trabajo y productos';tr = 'Rapor, işlerin ve ürünlerin standartları ve teknolojileri hakkında bilgi sağlar.';it = 'Il report fornisce informazioni sugli standard e le tecnologie dei lavori e degli articoli';de = 'Der Bericht enthält Informationen über Normen und Technologien für Arbeit und Produkte.'");
	Report.SearchSettings.FieldDescriptions = NStr("en = 'Products and services
	                                               |Technological operation
	                                               |Accounting price'; 
	                                               |ru = 'Номенклатура
	                                               |Технологическая операция
	                                               |Учетная цена';
	                                               |pl = 'Produkty i usługi
	                                               |Technologiczna działalność
	                                               |Cena ewidencyjna';
	                                               |es_ES = 'Productos y servicios
	                                               |Operación tecnológica
	                                               |Precio contable';
	                                               |es_CO = 'Productos y servicios
	                                               |Operación tecnológica
	                                               |Precio contable';
	                                               |tr = 'Ürünler ve hizmetler 
	                                               |Teknolojik operasyon 
	                                               |Hesaplama fiyatı';
	                                               |it = 'Articoli
	                                               |Operazioni tecnologiche
	                                               |Prezzo contabile';
	                                               |de = 'Produkte und Dienstleistungen
	                                               |Technologische Operation
	                                               |Buchführungspreis'");
	Report.SearchSettings.FilterParameterDescriptions = NStr("en = 'Date of calculation
	                                                       |Prices kind
	                                                       |Products
	                                                       |Characteristic
	                                                       |Specification'; 
	                                                       |ru = 'Дата расчета
	                                                       |Вид цен
	                                                       |Номенклатура
	                                                       |Вариант
	                                                       |Спецификация';
	                                                       |pl = 'Data kalkulacji
	                                                       |Rodzaje cen
	                                                       |Towary
	                                                       |Charakterystyka
	                                                       |Specyfikacja';
	                                                       |es_ES = 'Fecha del cálculo
	                                                       |Tipo de precios
	                                                       |Productos
	                                                       |Característica
	                                                       |Especificación';
	                                                       |es_CO = 'Fecha del cálculo
	                                                       |Tipo de precios
	                                                       |Productos
	                                                       |Característica
	                                                       |Especificación';
	                                                       |tr = 'Hesaplama tarihi 
	                                                       |Fiyat türü
	                                                       | Ürünler 
	                                                       |Karakteristik
	                                                       | Şartname';
	                                                       |it = 'Data di calcolo
	                                                       |Tipologia di prezzo
	                                                       |Articolo
	                                                       |Caratteristica
	                                                       |Specifica';
	                                                       |de = 'Datum der Berechnung
	                                                       |Preise Art
	                                                       |Produkte
	                                                       |Charakteristik
	                                                       |Spezifikation'");
	// end Drive.FullVersion
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.TrialBalance, "TBS");
	OptionSettings.Details = NStr("en = 'Opening balance, debits, credits, closing balance by GL accounts'; ru = 'Начальный остаток, приходы, расходы, конечный остаток по счетам учета.';pl = 'Saldo początkowe, obciążenia, kredyty, saldo końcowe według kont księgowych';es_ES = 'Saldo inicial, deudas, haberes, saldo final por cuentas del libro mayor';es_CO = 'Saldo inicial, deudas, haberes, saldo final por cuentas del libro mayor';tr = 'Muhasebe hesaplarına göre açılış bakiyesi, borçlar, krediler ve kapanış bakiyesi';it = 'Saldo di apertura, debiti, crediti, saldo di chiusura per conti mastro';de = 'Anfangssaldo, Soll, Haben, Abschlusssaldo nach Hauptbuch-Konten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.TrialBalanceFinancial, "TBFS");
	OptionSettings.Details = NStr("en = 'Opening balance, debits, credits, closing balance by GL accounts'; ru = 'Начальный остаток, приходы, расходы, конечный остаток по счетам учета.';pl = 'Saldo początkowe, obciążenia, kredyty, saldo końcowe według kont księgowych';es_ES = 'Saldo inicial, deudas, haberes, saldo final por cuentas del libro mayor';es_CO = 'Saldo inicial, deudas, haberes, saldo final por cuentas del libro mayor';tr = 'Muhasebe hesaplarına göre açılış bakiyesi, borçlar, krediler ve kapanış bakiyesi';it = 'Saldo di apertura, debiti, crediti, saldo di chiusura per conti mastro';de = 'Anfangssaldo, Soll, Haben, Abschlusssaldo nach Hauptbuch-Konten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.HoursWorked, "TotalForPeriod");
	OptionSettings.Details = NStr("en = 'Timesheet by pay codes'; ru = 'Табель по видам рабочего времени.';pl = 'Arkusz czasu pracy według kodów płac';es_ES = 'Plantilla horaria por códigos de pago';es_CO = 'Plantilla horaria por códigos de pago';tr = 'Ücret kodlarına göre zaman çizelgesi';it = 'Timesheet per codici di pagamento';de = 'Zeiterfassung nach Bezahlcodes'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.HoursWorked, "ByDays");
	OptionSettings.Details = NStr("en = 'Timesheet by days and pay codes'; ru = 'Табель по дням и видам рабочего времени';pl = 'Arkusz czasu pracy według dni i kodów płac';es_ES = 'Plantilla horaria por días y códigos de pago';es_CO = 'Plantilla horaria por días y códigos de pago';tr = 'Günlere ve ücret kodlarına göre zaman çizelgesi';it = 'Timesheet per giornate e codici pagamento';de = 'Zeiterfassung nach Tagen und Zahlungscodes'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesVariance, "Default");
	OptionSettings.Details = NStr("en = 'Sales target vs actual'; ru = 'План-факт по продажам.';pl = 'Plan sprzedaży w porównaniu ze sprzedażą faktyczną';es_ES = 'Objetivo de venta vs actual';es_CO = 'Objetivo de venta vs actual';tr = 'Hedef ve gerçekleşen satış';it = 'Obiettivo di vendita vs effettivo';de = 'Umsatzziel vs. Istwert'");
	
	// begin Drive.FullVersion
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProductionVarianceAnalysis, "Default");
	OptionSettings.Details = NStr("en = 'The report is designed to perform variance analysis of performed works, services rendered, manufacture of products'; ru = 'Отчет предназначен для план-фактного анализа выполнения работ, оказания услуг, производства продукции.';pl = 'Raport służy do przeprowadzania analizy wariancji wykonanych prac, świadczonych usług, wytwarzania produktów';es_ES = 'El informe está diseñado para realizar el análisis de la varianza de los trabajos realizados, los servicios prestados y la fabricación de productos';es_CO = 'El informe está diseñado para realizar el análisis de la varianza de los trabajos realizados, los servicios prestados y la fabricación de productos';tr = 'Rapor, gerçekleştirilen işlerin, sunulan hizmetlerin, ürünlerin imalatının fark analizini yapmak üzere tasarlanmıştır.';it = 'Il report è stato progettato per eseguire l''analisi delle variazioni di lavori svolti, servizi resi, produzione di prodotti';de = 'Der Bericht wurde entwickelt, um eine Abweichungsanalyse von ausgeführten Arbeiten, erbrachten Dienstleistungen, Herstellung von Produkten durchzuführen'");
	// end Drive.FullVersion
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PaymentCalendar, "Default");
	OptionSettings.Details = NStr("en = 'Cash flow projection'; ru = 'Планирование ДДС';pl = 'Preliminarz płatności';es_ES = 'Calendario de pagos';es_CO = 'Calendario de pagos';tr = 'Nakit akışı projeksiyonu';it = 'Scadenzario';de = 'Cashflow-Projektion'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProfitAndLossStatement, "Default");
	OptionSettings.Details = NStr("en = 'Profit and loss statement'; ru = 'Отчет о прибылях и убытках.';pl = 'Raport zysków i strat';es_ES = 'Lucro y pérdida extracto';es_CO = 'Lucro y pérdida extracto';tr = 'Kâr-zarar raporu';it = 'Conto economico';de = 'Gewinn- und Verlustrechnung'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.BudgetedBalanceSheet, "Default");
	OptionSettings.Details = NStr("en = 'Budgeted balance sheet'; ru = 'Прогнозный баланс.';pl = 'Planowany bilans';es_ES = 'Hoja de balance presupuestado';es_CO = 'Hoja de balance presupuestado';tr = 'Bütçelenmiş bilanço';it = 'Stato patrimoniale previsionale';de = 'Geplante Bilanz'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.BudgetedBalanceSheetVariance, "Default");
	OptionSettings.Details = NStr("en = 'Budgeted balance sheet vs actual'; ru = 'Балансовый отчет план-факт.';pl = 'Budżetowany bilans kontra faktyczny';es_ES = 'Hoja de balance presupuestado vs actual';es_CO = 'Hoja de balance presupuestado vs actual';tr = 'Gerçek bilançoya karşı bütçelendirilmiş bilanço';it = 'Stato patrimoniale previsionale vs effettivo';de = 'Geplante Bilanz vs. Ist-Bilanz'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "Default");
	OptionSettings.Details = NStr("en = 'Quantity and net sales by customers and products'; ru = 'Количество и чистые продажи по покупателям и номенклатуре';pl = 'Ilość i sprzedaż netto według nabywców i produktów';es_ES = 'Cantidad y ventas netas por clientes y productos';es_CO = 'Cantidad y ventas netas por clientes y productos';tr = 'Müşteri ve ürünlere göre miktar ve net satışlar';it = 'Quantità e vendite nette per clienti e articoli';de = 'Menge und Nettoumsatz nach Kunden und Produkten'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "GrossProfit");
	OptionSettings.Details = NStr("en = 'Net sales, COGS, gross profit, and margin by products'; ru = 'Чистые продажи, себестоимость, валовая прибыль и рентабельность по номенклатуре.';pl = 'Sprzedaż netto, KWS, zysk brutto i marża według produktów';es_ES = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por productos';es_CO = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por productos';tr = 'Ürünlere göre net satışlar, SMM, brüt kâr ve marj';it = 'Vendite nette, Costo Merci Vendute (COGS), profitto lordo e margine per articoli';de = 'Nettoumsatz, Wareneinsatz, Bruttoertrag und Marge nach Produkten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "GrossProfitByProductsCategories");
	OptionSettings.Details = NStr("en = 'Net sales, COGS, gross profit, and margin by products categories'; ru = 'Чистые продажи, себестоимость, валовая прибыль и маржа по категориям номенклатуры.';pl = 'Sprzedaż netto, KWS, zysk brutto i marża według kategorii produktów';es_ES = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por categorías de productos';es_CO = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por categorías de productos';tr = 'Ürün kategorilerine göre net satışlar, SMM, brüt kâr ve marj';it = 'Vendite nette, Costo Merci Vendute (COGS), profitto lordo e margine per categorie di articoli';de = 'Nettoumsatz, Wareneinsatz, Bruttoertrag und Marge nach Produktkategorien'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "GrossProfitByCustomers");
	OptionSettings.Details = NStr("en = 'Net sales, COGS, gross profit, and margin by customers'; ru = 'Чистые продажи, себестоимость, валовая прибыль и маржа по покупателям.';pl = 'Sprzedaż netto, KWS, zysk brutto i marża według nabywców';es_ES = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por clientes';es_CO = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por clientes';tr = 'Müşterilere göre net satışlar, SMM, brüt kâr ve marj';it = 'Vendite nette, Costo Merci Vendute (COGS), profitto lordo e margine per clienti';de = 'Nettoumsatz, Wareneinsatz, Bruttoertrag und Marge nach Kunden'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "GrossProfitByCustomersWithZeroInvoice");
	OptionSettings.Details = NStr("en = 'Net sales, COGS, gross profit, and margin by customers including zero invoices'; ru = 'Чистые продажи, себестоимость, валовая прибыль и маржа по покупателям, включая нулевые инвойсы';pl = 'Sprzedaż netto, KWS, zysk brutto, i marża według nabywców w tym faktury zerowe';es_ES = 'Ventas netas, Costo de los bienes vendidos, ganancia bruta y margen por clientes, incluyendo facturas con importe cero';es_CO = 'Ventas netas, Costo de los bienes vendidos, ganancia bruta y margen por clientes, incluyendo facturas con importe cero';tr = 'Müşterilere göre sıfır bedelli fatura içeren net satışlar, satılan malların maliyeti, brüt kar, kazanç';it = 'Vendite nette, Costo delle Merci Vendute (COGS), e margine per clienti incluse Fattura a zero';de = 'Nettoverkauf, COGS, Bruttoertrag und Marge nach Kunden einschließlich Nullrechnungen'");
	OptionSettings.VisibleByDefault = False;
	OptionSettings.FunctionalOptions.Add("UseZeroInvoiceSales");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "GrossProfitByManagers");
	OptionSettings.Details = NStr("en = 'Net sales, COGS, gross profit, and margin by managers'; ru = 'Чистые продажи, себестоимость продаж, валовая прибыль и маржа по менеджерам.';pl = 'Sprzedaż netto, KWS, zysk brutto oraz marża według kierowników';es_ES = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por gerentes';es_CO = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por gerentes';tr = 'Yöneticilere göre net satışlar, SMM, brüt kâr ve marj';it = 'Vendite nette, Costo Merci Vendute (COGS), profitto lordo e margine per responsabile';de = 'Nettoumsatz, Wareneinsatz, Bruttoertrag und Marge nach den Managern'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "GrossProfitBySalesRep");
	OptionSettings.Details = NStr("en = 'Net sales, COGS, gross profit, and margin by sales reps'; ru = 'Чистые продажи, себестоимость, валовая прибыль и маржа по торговым представителям';pl = 'Sprzedaż netto, KWS, zysk brutto i marża według przedstawicieli handlowych';es_ES = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por agentes de venta';es_CO = 'Ventas netas, coste de productos vendidos, beneficio bruto y margen de contribución por agentes de venta';tr = 'Satış temsilcilerine göre net satışlar, SMM, brüt kâr ve marj';it = 'Vendite nette, Costo Merci Vendute (COGS), profitto lordo e margine per rappresentanti di vendita';de = 'Nettoumsatz, Wareneinsatz, Bruttoertrag und Marge nach den Vertriebsmitarbeitern'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "SalesDynamics");
	OptionSettings.Details = NStr("en = 'Net sales,	COGS, gross profit, and margin by months, displayed as a chart.'; ru = 'Чистые продажи,	себестоимость, валовая прибыль и рентабельность по месяцам в виде диаграммы.';pl = 'Sprzedaż netto,	 KWS, zysk brutto i marża według miesięcy, wyświetlane jako wykres.';es_ES = 'Ventas netas,	Costo de los bienes vendidos, ganancia bruta y margen por meses en forma de diagrama.';es_CO = 'Ventas netas,	Costo de los bienes vendidos, ganancia bruta y margen por meses en forma de diagrama.';tr = 'Grafik olarak gösterilen, aylara göre net satışlar, 	SMM, brüt kâr ve marj.';it = 'Vendite nette,	Costo della merce, profitto lordo e margine per mese mostrato come grafico.';de = 'Nettoumsatz,	Wareneinsatz, Bruttoertrag und Marge nach Monaten, dargestellt als Diagramm.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "SalesDynamicsByProducts");
	OptionSettings.Details = NStr("en = 'Sales trend by products and days, displayed as a chart.'; ru = 'Динамика продаж по номенклатуре и дням в виде диаграммы';pl = 'Trend sprzedaży według produktów i dni, wyświetlany jako wykres.';es_ES = 'Tendencias de venta por productos y días mostradas como diagrama.';es_CO = 'Tendencias de venta por productos y días mostradas como diagrama.';tr = 'Grafik olarak gösterilen, ürünlere ve günlere göre satış eğilimi';it = 'Andamento delle vendite per articolo e giorni mostrato come grafico.';de = 'Umsatzentwicklung nach Produkten und Tagen, dargestellt als Diagramm.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "SalesDynamicsByProductsCategories");
	OptionSettings.Details = NStr("en = 'Sales trend by product categories and days, displayed as a chart.'; ru = 'Динамика продаж по категориям номенклатуры и дням в виде диаграммы';pl = 'Trend sprzedaży według kategorii produktów i dni, wyświetlany jako wykres.';es_ES = 'Tendencias de venta por categorías productos y días mostradas como diagrama.';es_CO = 'Tendencias de venta por categorías productos y días mostradas como diagrama.';tr = 'Grafik olarak gösterilen, ürün kategorilerine ve günlere göre satış eğilimi';it = 'Andamento delle vendite per categoria articolo e giorni mostrato come grafico.';de = 'Umsatzentwicklung nach Produktkategorien und Tagen, dargestellt als Diagramm.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "SalesDynamicsByCustomers");
	OptionSettings.Details = NStr("en = 'Sales trend by customers and days, displayed as a chart.'; ru = 'Динамика продаж по покупателям и дням в виде диаграммы';pl = 'Trend sprzedaży według nabywców i dni, wyświetlany, jako wykres.';es_ES = 'Tendencias de venta por clientes y días mostradas como diagrama.';es_CO = 'Tendencias de venta por clientes y días mostradas como diagrama.';tr = 'Grafik olarak gösterilen, müşteriler ve günlere göre satış eğilimi';it = 'Andamento delle vendite per clieni e giorni mostrato come grafico.';de = 'Umsatzentwicklung nach Kunden und Tagen, dargestellt als Diagramm.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "SalesDynamicsByManagers");
	OptionSettings.Details = NStr("en = 'Sales trend by managers and days, displayed as a chart.'; ru = 'Динамика продаж по менеджерам и дням в виде диаграммы.';pl = 'Trend sprzedaży według kierowników i dni, wyświetlany jako wykres.';es_ES = 'Tendencias de venta por gerentes y días mostradas como diagrama.';es_CO = 'Tendencias de venta por gerentes y días mostradas como diagrama.';tr = 'Grafik olarak gösterilen, yöneticilere ve günlere göre satış eğilimi.';it = 'Trend di vendita per responsabile e giorni, mostrato sotto forma di diagramma.';de = 'Umsatzentwicklung nach Managern und Tagen, dargestellt als Diagramm.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.NetSales, "SalesDynamicsBySalesRep");
	OptionSettings.Details = NStr("en = 'Sales trend by sales rep and days, displayed as a chart.'; ru = 'Динамика продаж по торговым представителям и дням в виде диаграммы.';pl = 'Trend sprzedaży według przedstawicieli handlowych i dni, wyświetlany jako wykres.';es_ES = 'Tendencia de venta por agentes de ventas y días mostradas como diagrama.';es_CO = 'Tendencia de venta por agentes de ventas y días mostradas como diagrama.';tr = 'Grafik olarak gösterilen, satış temsilcileri ve günlere göre satış eğilimi.';it = 'Trend di vendita per agente di vendita e giorni, mostrato sotto forma di diagramma.';de = 'Umsatzentwicklung nach Verkaufsberichten und Tagen, dargestellt als Diagramm.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.Backorders, "Statement");
	OptionSettings.Details = NStr("en = 'Goods that are ordered by customers and currently not in stock but had been ordered in a purchase order'; ru = 'Товары, которые заказаны покупателями и в настоящее время отсутствуют на складе, но были включены в заказ поставщику';pl = 'Towary, które są zamówione przez klientów i których obecnie nie ma w zapasach, ale zostały zamówione w ramach zamówienia zakupu';es_ES = 'Mercancías que se han pedido por clientes, y actualmente no se encuentran en stock, pero se habían pedido en una orden de compra';es_CO = 'Mercancías que se han pedido por clientes, y actualmente no se encuentran en stock, pero se habían pedido en una orden de compra';tr = 'Müşteriler tarafından sipariş edilen ve bir satın alma siparişinde sipariş edilmesine rağmen şu anda stokta olmayan mallar';it = 'Merci che sono state ordinate dai clienti e attualmente non sono in stock, ma sono state ordinate in un ordine di acquisto';de = 'Waren, die von Kunden bestellt worden und derzeit nicht im Bestand sind, aber in einer Bestellung an Lieferanten bestellt wurden'");
	// begin Drive.FullVersion
	OptionSettings.Details = NStr("en = 'Goods that are ordered by customers and currently not in stock but had been ordered in a purchase or production order'; ru = 'В отчете отражаются изменение данных о заказах покупателей, выполнение которых обеспечивается за счет поступлений по заказам поставщикам или на производство.';pl = 'Towary, zamówione przez nabywców i których nie ma na stanie ale zostały zamówione w zakupie lub w zleceniu produkcyjnym';es_ES = 'Mercancías que se han pedido por clientes, y actualmente no se encuentran en stock, pero se habían pedido en un pedido o un orden de producción';es_CO = 'Mercancías que se han pedido por clientes, y actualmente no se encuentran en stock, pero se habían pedido en un pedido o un orden de producción';tr = 'Müşteriler tarafından sipariş edilen ve bir satın alma siparişinde veya üretim emrinde sipariş edilmesine rağmen şu anda stokta olmayan mallar';it = 'Merci che sono state ordinate dai clienti e attualmente non sono in stock, ma era sono state ordinate in un ordine di acquisto o di produzione';de = 'Waren, die von Kunden bestellt worden sind und derzeit nicht im Bestand sind, aber in einer Bestellung an Lieferanten oder Produktionsauftrag bestellt wurden'");
	// end Drive.FullVersion
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.Backorders, "Balance");
	OptionSettings.Details = NStr("en = 'Remaining backorder items'; ru = 'В отчете отражаются данные о заказах покупателей, выполнение которых обеспечивается за счет поступлений по другим заказам - поставщикам и на комплектацию, производство';pl = 'Pozostałe artykuły zaległych zamówień';es_ES = 'Artículos del pedido atrasado restante';es_CO = 'Artículos del pedido atrasado restante';tr = 'Kalan karşılanamayan sipariş ürünleri';it = 'Restanti elementi in arretrato';de = 'Verbleibende Artikel im Auftragsrückstand'");
	OptionSettings.VisibleByDefault = False;
	
	Report = ReportsOptions.ReportDetails(Settings, Metadata.Reports.PayStatementFixedTemplate);
	ReportsOptions.SetOutputModeInReportPanes(Settings, Report, True);
	Report.Details = NStr("en = 'Payroll of an arbitrary form. Intended for internal reporting of the company'; ru = 'Расчетная ведомость произвольной формы. Предназначена для внутренней отчетности предприятия.';pl = 'Lista płac w dowolnej formie. Przeznaczona do wewnętrznej sprawozdawczości firmy';es_ES = 'Nómina de un formulario arbitrario. Destinado para informes internos de la empresa';es_CO = 'Nómina de un formulario arbitrario. Destinado para informes internos de la empresa';tr = 'Serbest form maaş bordrosu. İş yerinin dahili raporlaması için kullanılır';it = 'Libro paga di forma arbitraria. Destinato al report interno dell''azienda';de = 'Lohn-und Gehaltsabrechnung einer beliebigen Form. Vorgesehen für die interne Berichterstattung der Firma'");
	Report.SearchSettings.FieldDescriptions = NStr("en = 'Employee ID
	                                              |Employee
	                                              |Position
	                                              |Rate
	                                              |Department
	                                              |Company'; 
	                                              |ru = 'Табельный номер
	                                              |Сотрудник
	                                              |Должность
	                                              |Тарифная ставка
	                                              |Подразделение
	                                              |Организация';
	                                              |pl = 'Identyfikator pracownika
	                                              |Pracownik
	                                              |Stanowisko
	                                              |Stawka
	                                              |Dział
	                                              |Firma';
	                                              |es_ES = 'Identificador del empleado
	                                              |Empleado
	                                              |Posición
	                                              |Tasa
	                                              |Departamento
	                                              |Empresa';
	                                              |es_CO = 'Identificador del empleado
	                                              |Empleado
	                                              |Posición
	                                              |Tasa
	                                              |Departamento
	                                              |Empresa';
	                                              |tr = 'Çalışan Kimliği
	                                              |Çalışan
	                                              |Pozisyon
	                                              |Ücret
	                                              |Bölüm
	                                              |İş yeri';
	                                              |it = 'Matricola Dipendente 
	                                              |Dipendente
	                                              |Inquadramento
	                                              |Costo orario
	                                              |Reparto
	                                              |Azienda';
	                                              |de = 'Mitarbeiter-ID
	                                              |Mitarbeiter
	                                              |Position
	                                              |Tarif
	                                              |Abteilung
	                                              |Firma'");
	Report.SearchSettings.FilterParameterDescriptions = NStr("en = 'Registration period
	                                                             |Department
	                                                             |Currency
	                                                             |Company'; 
	                                                             |ru = 'Период регистрации
	                                                             |Подразделение
	                                                             |Валюта
	                                                             |Организация';
	                                                             |pl = 'Okres rejestracji
	                                                             |Dział
	                                                             |Waluta
	                                                             |Firma';
	                                                             |es_ES = 'Período de registro
	                                                             |Departamento
	                                                             |Moneda
	                                                             |Empresa';
	                                                             |es_CO = 'Período de registro
	                                                             |Departamento
	                                                             |Moneda
	                                                             |Empresa';
	                                                             |tr = 'Kayıt dönemi
	                                                             |Bölüm
	                                                             |Para birimi
	                                                             |İş yeri';
	                                                             |it = 'Periodo di registrazione
	                                                             |Reparto
	                                                             |Valuta
	                                                             |Azienda';
	                                                             |de = 'Anmeldezeitraum
	                                                             |Abteilung
	                                                             |Währung
	                                                             |Firma'");
	
	Report = ReportsOptions.ReportDetails(Settings, Metadata.Reports.PaySlips);
	ReportsOptions.SetOutputModeInReportPanes(Settings, Report, True);
	Report.Details = NStr("en = 'Payslips for a period'; ru = 'Расчетные листки за период.';pl = 'Paski wynagrodzenia za okres';es_ES = 'Nóminas por período';es_CO = 'Nóminas por período';tr = 'Dönem için maaş bordroları';it = 'Cedolini paga per un periodo';de = 'Lohnzettel für einen Zeitraum'");
	Report.SearchSettings.FieldDescriptions = NStr("en = 'Employee ID
	                                              |Employee
	                                              |Position
	                                              |Rate
	                                              |Department
	                                              |Company'; 
	                                              |ru = 'Табельный номер
	                                              |Сотрудник
	                                              |Должность
	                                              |Тарифная ставка
	                                              |Подразделение
	                                              |Организация';
	                                              |pl = 'Identyfikator pracownika
	                                              |Pracownik
	                                              |Stanowisko
	                                              |Stawka
	                                              |Dział
	                                              |Firma';
	                                              |es_ES = 'Identificador del empleado
	                                              |Empleado
	                                              |Posición
	                                              |Tasa
	                                              |Departamento
	                                              |Empresa';
	                                              |es_CO = 'Identificador del empleado
	                                              |Empleado
	                                              |Posición
	                                              |Tasa
	                                              |Departamento
	                                              |Empresa';
	                                              |tr = 'Çalışan Kimliği
	                                              |Çalışan
	                                              |Pozisyon
	                                              |Ücret
	                                              |Bölüm
	                                              |İş yeri';
	                                              |it = 'Matricola Dipendente 
	                                              |Dipendente
	                                              |Inquadramento
	                                              |Costo orario
	                                              |Reparto
	                                              |Azienda';
	                                              |de = 'Mitarbeiter-ID
	                                              |Mitarbeiter
	                                              |Position
	                                              |Tarif
	                                              |Abteilung
	                                              |Firma'");
	Report.SearchSettings.FilterParameterDescriptions = NStr("en = 'Registration period
	                                                             |Department
	                                                             |Currency
	                                                             |Employee'; 
	                                                             |ru = 'Период регистрации
	                                                             |Подразделение
	                                                             |Валюта
	                                                             |Сотрудник';
	                                                             |pl = 'Okres rejestracji
	                                                             |Dział
	                                                             |Waluta
	                                                             |Pracownik';
	                                                             |es_ES = 'Período de registro
	                                                             |Departamento
	                                                             |Moneda
	                                                             |Empleado';
	                                                             |es_CO = 'Período de registro
	                                                             |Departamento
	                                                             |Moneda
	                                                             |Empleado';
	                                                             |tr = 'Kayıt dönemi
	                                                             |Bölüm
	                                                             |Para Birimi
	                                                             |Çalışan';
	                                                             |it = 'Periodo di registrazione
	                                                             |Reparto
	                                                             |Valuta
	                                                             |Dipendente';
	                                                             |de = 'Anmeldezeitraum
	                                                             |Abteilung
	                                                             |Währung
	                                                             |Mitarbeiter'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfTaxAccount, "Statement");
	OptionSettings.Details = NStr("en = 'Taxes opening balance, accruals, payments, closing balance'; ru = 'Налоги – начальный остаток, начисления, выплаты, конечный остаток.';pl = 'Podatki - Saldo początkowe, naliczenia, płatności, saldo końcowe';es_ES = 'Saldo inicial de impuestos, devengo, pagos, saldo final';es_CO = 'Saldo inicial de impuestos, devengo, pagos, saldo final';tr = 'Vergiler açılış bakiyesi, tahakkuklar, ödemeler, kapanış bakiyesi';it = 'Imposte saldo di apertura, maturato, pagamenti, saldo di chiusura';de = 'Steuern Anfangssaldo, Rückstellungen, Zahlungen, Abschlusssaldo'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StatementOfTaxAccount, "Balance");
	OptionSettings.Details = NStr("en = 'The balance of tax payables'; ru = 'Остаток задолженности по налогам';pl = 'Saldo zobowiązań podatkowych';es_ES = 'Saldo de los impuestos pagables';es_CO = 'Saldo de los impuestos pagables';tr = 'Vergi borcu bakiyesi';it = 'Saldo delle imposte da pagare';de = 'Der Saldo der Steuerverbindlichkeiten'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PayStatements, "Statement");
	OptionSettings.Details = NStr("en = 'Salary opening balance, earnings, payments, closing balance'; ru = 'Заработная плата – начальный остаток, начисления, выплаты, конечный остаток.';pl = 'Saldo początkowe wynagrodzeń, zarobki, płatności, saldo końcowe';es_ES = 'Saldo inicial del salario, ganancias, pagos, saldo final';es_CO = 'Saldo inicial del salario, ganancias, pagos, saldo final';tr = 'Maaş açılış bakiyesi, kazançlar, ödemeler, kapanış bakiyesi';it = 'Stipendi saldo di apertura, compensi, pagamenti, saldo di chiusura';de = 'Gehaltsanfangssaldo, Bezüge, Zahlungen, Abschlusssaldo'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PayStatements, "Balance");
	OptionSettings.Details = NStr("en = 'The balance of salary payable'; ru = 'Остаток задолженности по заработной плате';pl = 'Saldo wypłacanego wynagrodzenia';es_ES = 'Saldo del salario pagable';es_CO = 'Saldo del salario pagable';tr = 'Ödenecek maaş bakiyesi';it = 'Il saldo degli stipendi da pagare';de = 'Der Saldo der Gehaltsverbindlichkeiten'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PayStatements, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Salary opening balance, earnings, payments, closing balance'; ru = 'Заработная плата – начальный остаток, начисления, выплаты, конечный остаток.';pl = 'Saldo początkowe wynagrodzeń, zarobki, płatności, saldo końcowe';es_ES = 'Saldo inicial del salario, ganancias, pagos, saldo final';es_CO = 'Saldo inicial del salario, ganancias, pagos, saldo final';tr = 'Maaş açılış bakiyesi, kazançlar, ödemeler, kapanış bakiyesi';it = 'Stipendi saldo di apertura, compensi, pagamenti, saldo di chiusura';de = 'Gehaltsanfangssaldo, Bezüge, Zahlungen, Abschlusssaldo'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PayStatements, "BalanceInCurrency");
	OptionSettings.Details = NStr("en = 'The balance of salary payable'; ru = 'Остаток задолженности по заработной плате';pl = 'Saldo wypłacanego wynagrodzenia';es_ES = 'Saldo del salario pagable';es_CO = 'Saldo del salario pagable';tr = 'Ödenecek maaş bakiyesi';it = 'Il saldo degli stipendi da pagare';de = 'Der Saldo der Gehaltsverbindlichkeiten'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AdvanceHolders, "Statement");
	OptionSettings.Details = NStr("en = 'Advance holders debt opening balance, claims, payments, closing balance'; ru = 'Долг подотчетных лиц: начальный остаток, выданные, платежи, конечный остаток.';pl = 'Zaliczkobiorcy na poczet salda otwarcia, roszczenia, płatności, saldo końcowe';es_ES = 'Saldo inicial de la deuda de los titulares de anticipo, reclamaciones, pagos, saldo final';es_CO = 'Saldo inicial de la deuda de los titulares de anticipo, reclamaciones, pagos, saldo final';tr = 'Avans sahibinin borç açılış bakiyesi, talep, ödemeleri, kapanış bakiyesi';it = 'Debito titolari di anticipo saldo di apertura, richieste, pagamenti, saldo di chiusura';de = 'Abrechnungspflichtige Personen -Schulden Anfangssaldo, Forderungen, Zahlungen, Abschlusssaldo'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AdvanceHolders, "Balance");
	OptionSettings.Details = NStr("en = 'Debt balance of advance holders'; ru = 'Остаток долга подотчетных лиц';pl = 'Saldo zobowiązań z zaliczkobiorcami';es_ES = 'Saldo de la deuda de los titulares de anticipo';es_CO = 'Saldo de la deuda de los titulares de anticipo';tr = 'Avans sahiplerinin borç bakiyesi';it = 'Saldo debito dei titolari di anticipo';de = 'Schuldsaldo der abrechnungspflichtigen Personen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AdvanceHolders, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Advance holders debt opening balance, claims, payments, closing balance'; ru = 'Долг подотчетных лиц: начальный остаток, выданные, платежи, конечный остаток.';pl = 'Zaliczkobiorcy na poczet salda otwarcia, roszczenia, płatności, saldo końcowe';es_ES = 'Saldo inicial de la deuda de los titulares de anticipo, reclamaciones, pagos, saldo final';es_CO = 'Saldo inicial de la deuda de los titulares de anticipo, reclamaciones, pagos, saldo final';tr = 'Avans sahibinin borç açılış bakiyesi, talep, ödemeleri, kapanış bakiyesi';it = 'Debito titolari di anticipo saldo di apertura, richieste, pagamenti, saldo di chiusura';de = 'Abrechnungspflichtige Personen -Schulden Anfangssaldo, Forderungen, Zahlungen, Abschlusssaldo'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AdvanceHolders, "BalanceInCurrency");
	OptionSettings.Details = NStr("en = 'Debt balance of advance holders'; ru = 'Остаток долга подотчетных лиц';pl = 'Saldo zobowiązań z zaliczkobiorcami';es_ES = 'Saldo de la deuda de los titulares de anticipo';es_CO = 'Saldo de la deuda de los titulares de anticipo';tr = 'Avans sahiplerinin borç bakiyesi';it = 'Saldo debito dei titolari di anticipo';de = 'Schuldsaldo der abrechnungspflichtigen Personen'");
	OptionSettings.VisibleByDefault = False;
	
	// Customer statement
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CustomerStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, sales, payments, advances, and closing balance.'; ru = 'Начальный остаток, продажи, платежи, авансы и конечный остаток.';pl = 'Saldo początkowe, sprzedaż, płatności, zaliczki i saldo zamknięcia.';es_ES = 'Saldo de apertura, ventas, pagos, pagos anticipados y saldo de cierre.';es_CO = 'Saldo de apertura, ventas, pagos, pagos anticipados y saldo de cierre.';tr = 'Açılış bakiyesi, satışlar, ödemeler, avanslar ve kapanış bakiyesi.';it = 'Saldo iniziale, vendite, pagamenti, pagamenti anticipati e bilancio di chiusura.';de = 'Anfangssaldo, Verkäufe, Zahlungen, Vorauszahlungen und Abschlusssaldo.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CustomerStatement, "Balance");
	OptionSettings.Details = NStr("en = 'Outstanding debts and advances.'; ru = 'Неоплаченная задолженность и авансы.';pl = 'Zaległe zobowiązania i zaliczki.';es_ES = 'Deudas y anticipos pendientes.';es_CO = 'Deudas y anticipos pendientes.';tr = 'Ödenmemiş borçlar ve avanslar.';it = 'Debiti e pagamenti anticipati insoluti.';de = 'Ausstehende Schulden und Aufschläge.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CustomerStatement, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Opening balance, sales, payments, advances, and closing balance.'; ru = 'Начальный остаток, продажи, платежи, авансы и конечный остаток.';pl = 'Saldo początkowe, sprzedaż, płatności, zaliczki i saldo zamknięcia.';es_ES = 'Saldo de apertura, ventas, pagos, pagos anticipados y saldo de cierre.';es_CO = 'Saldo de apertura, ventas, pagos, pagos anticipados y saldo de cierre.';tr = 'Açılış bakiyesi, satışlar, ödemeler, avanslar ve kapanış bakiyesi.';it = 'Saldo iniziale, vendite, pagamenti, pagamenti anticipati e bilancio di chiusura.';de = 'Anfangssaldo, Verkäufe, Zahlungen, Vorauszahlungen und Abschlusssaldo.'");
	OptionSettings.VisibleByDefault = True;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CustomerStatement, "BalanceInCurrency");
	OptionSettings.Details = NStr("en = 'Outstanding debts and advances.'; ru = 'Неоплаченная задолженность и авансы.';pl = 'Zaległe zobowiązania i zaliczki.';es_ES = 'Deudas y anticipos pendientes.';es_CO = 'Deudas y anticipos pendientes.';tr = 'Ödenmemiş borçlar ve avanslar.';it = 'Debiti e pagamenti anticipati insoluti.';de = 'Ausstehende Schulden und Aufschläge.'");
	OptionSettings.VisibleByDefault = False;
	
	// Accounts receivable
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsReceivable, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, sales, payments, and closing balance, separated to credit and advance payments'; ru = 'В отчете отображаются сведения о расчетах организации с покупателями, включая заказы и договоры, в рамках которых заключались сделки между организацией и контрагентами.';pl = 'Saldo początkowe, sprzedaż, płatności i saldo końcowe, rozdzielone na płatności kredytowe i zaliczkowe';es_ES = 'Saldo de apertura, ventas, pagos y saldo de cierre, separados para el crédito y los pagos anticipados';es_CO = 'Saldo de apertura, ventas, pagos y saldo de cierre, separados para el crédito y los pagos anticipados';tr = 'Kredi ve avans ödemelerine ayrılmış açılış bakiyesi, satışlar, ödemeler ve kapanış bakiyesi';it = 'Saldo di apertura, vendite, pagamenti, e il saldo di chiusura, separati al credito e per pagamenti anticipati';de = 'Anfangssaldo, Verkäufe, Zahlungen und Abschlusssaldo getrennt nach Haben und Vorauszahlungen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsReceivable, "Balance");
	OptionSettings.Details = NStr("en = 'Balance of receivables, advance payments, and overdue debts'; ru = 'Остаток по кредиторской задолженности, авансовым платежам и просроченной задолженности';pl = 'Saldo należności, zaliczki i długi przeterminowane';es_ES = 'Saldo de las cuentas a cobrar, pagos anticipados y deudas vencidas';es_CO = 'Saldo de las cuentas a cobrar, pagos anticipados y deudas vencidas';tr = 'Alacak bakiyesi, avans ödemeleri ve vadesi geçmiş borçlar';it = 'Saldo dei crediti, anticipi e i debiti scaduti';de = 'Saldo aus Forderungen, Vorauszahlungen und überfälligen Schulden'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsReceivable, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Opening balance, sales, payments, and closing balance, separated to credit and advance payments'; ru = 'В отчете отображаются сведения о расчетах организации с покупателями, включая заказы и договоры, в рамках которых заключались сделки между организацией и контрагентами.';pl = 'Saldo początkowe, sprzedaż, płatności i saldo końcowe, rozdzielone na płatności kredytowe i zaliczkowe';es_ES = 'Saldo de apertura, ventas, pagos y saldo de cierre, separados para el crédito y los pagos anticipados';es_CO = 'Saldo de apertura, ventas, pagos y saldo de cierre, separados para el crédito y los pagos anticipados';tr = 'Kredi ve avans ödemelerine ayrılmış açılış bakiyesi, satışlar, ödemeler ve kapanış bakiyesi';it = 'Saldo di apertura, vendite, pagamenti, e il saldo di chiusura, separati al credito e per pagamenti anticipati';de = 'Anfangssaldo, Verkäufe, Zahlungen und Abschlusssaldo getrennt nach Haben und Vorauszahlungen'");
	OptionSettings.VisibleByDefault = True;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsReceivable, "BalanceInCurrency");
	OptionSettings.Details = NStr("en = 'Balance of receivables, advance payments, and overdue debts'; ru = 'Остаток по кредиторской задолженности, авансовым платежам и просроченной задолженности';pl = 'Saldo należności, zaliczki i długi przeterminowane';es_ES = 'Saldo de las cuentas a cobrar, pagos anticipados y deudas vencidas';es_CO = 'Saldo de las cuentas a cobrar, pagos anticipados y deudas vencidas';tr = 'Alacak bakiyesi, avans ödemeleri ve vadesi geçmiş borçlar';it = 'Saldo dei crediti, anticipi e i debiti scaduti';de = 'Saldo aus Forderungen, Vorauszahlungen und überfälligen Schulden'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsReceivable, "StatementZeroInvoice");
	OptionSettings.Details = NStr("en = 'Opening balance, sales, payments, advances received, advances cleared, and closing balance including zero invoices'; ru = 'Начальный остаток, продажи, полученные авансы, зачтенные авансы и конечный остаток, включая нулевые инвойсы';pl = 'Saldo początkowe, sprzedaż, płatności, otrzymane zaliczki, rozliczone zaliczki, i saldo zamknięcia, w tym faktury zerowe';es_ES = 'Saldo inicial, ventas, pagos, anticipos recibidos, anticipos compensados y saldo final que incluye facturas con importe cero';es_CO = 'Saldo inicial, ventas, pagos, anticipos recibidos, anticipos compensados y saldo final que incluye facturas con importe cero';tr = 'Sıfır bedelli fatura içeren açılış bakiyesi, satışlar, ödemeler, alınan avanslar, temizlenen avanslar ve kapanış bakiyesi';it = 'Saldo iniziale, vendite, pagamenti, pagamenti anticipati ricevuti, pagamenti anticipati liquidati, e bilancio di chiusura incluse Fattura a zero';de = 'Anfangssaldo, Verkäufe, Zahlungen, erhaltene Vorauszahlungen, verrechnete Vorauszahlungen und Abschlusssaldo einschließlich Nullrechnungen'");
	OptionSettings.VisibleByDefault = False;
	OptionSettings.FunctionalOptions.Add("UseZeroInvoiceSales");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsReceivableTrend, "DebtDynamics");
	OptionSettings.Details = NStr("en = 'Receivables by periods displayed as a chart'; ru = 'Дебиторская задолженность по периодам в виде диаграммы.';pl = 'Należności według okresów wyświetlanych jako wykres';es_ES = 'Cuentas a cobrar por períodos mostradas como diagrama';es_CO = 'Cuentas a cobrar por períodos mostradas como diagrama';tr = 'Grafik olarak gösterilen dönemlere göre alacaklar';it = 'Crediti da ricevere per periodo mostrati come grafico';de = 'Forderungen nach Zeiträumen, als Diagramm dargestellt'");
	
	// Supplier statement
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SupplierStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, sales, payments, advances, and closing balance.'; ru = 'Начальный остаток, продажи, платежи, авансы и конечный остаток.';pl = 'Saldo początkowe, sprzedaż, płatności, zaliczki i saldo zamknięcia.';es_ES = 'Saldo de apertura, ventas, pagos, pagos anticipados y saldo de cierre.';es_CO = 'Saldo de apertura, ventas, pagos, pagos anticipados y saldo de cierre.';tr = 'Açılış bakiyesi, satışlar, ödemeler, avanslar ve kapanış bakiyesi.';it = 'Saldo iniziale, vendite, pagamenti, pagamenti anticipati e bilancio di chiusura.';de = 'Anfangssaldo, Verkäufe, Zahlungen, Vorauszahlungen und Abschlusssaldo.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SupplierStatement, "Balance");
	OptionSettings.Details = NStr("en = 'Outstanding debts and advances.'; ru = 'Неоплаченная задолженность и авансы.';pl = 'Zaległe zobowiązania i zaliczki.';es_ES = 'Deudas y anticipos pendientes.';es_CO = 'Deudas y anticipos pendientes.';tr = 'Ödenmemiş borçlar ve avanslar.';it = 'Debiti e pagamenti anticipati insoluti.';de = 'Ausstehende Schulden und Aufschläge.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SupplierStatement, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Opening balance, purchases, payments, advances, and closing balance.'; ru = 'Начальный остаток, закупки, платежи, авансы и конечный остаток.';pl = 'Saldo początkowe, zakupy, płatności, zaliczki i saldo zamknięcia.';es_ES = 'Saldo de apertura, compras, pagos, pagos anticipados y saldo de cierre.';es_CO = 'Saldo de apertura, compras, pagos, pagos anticipados y saldo de cierre.';tr = 'Açılış bakiyesi, satın almalar, ödemeler, avanslar ve kapanış bakiyesi.';it = 'Saldo iniziale, acquisti, pagamenti, pagamenti anticipati e bilancio di chiusura.';de = 'Anfangssaldo, Käufe, Zahlungen, Vorauszahlungen und Abschlusssaldo.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SupplierStatement, "BalanceInCurrency");
	OptionSettings.Details = NStr("en = 'Outstanding debts and advances.'; ru = 'Неоплаченная задолженность и авансы.';pl = 'Zaległe zobowiązania i zaliczki.';es_ES = 'Deudas y anticipos pendientes.';es_CO = 'Deudas y anticipos pendientes.';tr = 'Ödenmemiş borçlar ve avanslar.';it = 'Debiti e pagamenti anticipati insoluti.';de = 'Ausstehende Schulden und Aufschläge.'");
	OptionSettings.VisibleByDefault = False;
	
	// Accounts payable
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsPayable, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, purchases, payments, and closing balance, separated to credit and advance payments'; ru = 'В отчете отображаются сведения о расчетах организации с поставщиками, включая заказы и договоры, в рамках которых заключались сделки между организацией и контрагентами.';pl = 'Saldo początkowe, zakup, płatności oraz saldo końcowe, rozdzielone na płatności kredytowe i zaliczkowe';es_ES = 'Saldo de apertura, compras, pagos y saldo de cierre, separados para el crédito y los pagos anticipados';es_CO = 'Saldo de apertura, compras, pagos y saldo de cierre, separados para el crédito y los pagos anticipados';tr = 'Kredi ve avans ödemelerine ayrılmış açılış bakiyesi, satın almalar, ödemeler ve kapanış bakiyesi';it = 'Saldo di apertura, acquisti, pagamenti, e saldo di chiusura, separati da crediti e pagamenti anticipati';de = 'Anfangssaldo, Einkäufe, Zahlungen und Abschlusssaldo getrennt nach Haben und Vorauszahlungen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsPayable, "Balance");
	OptionSettings.Details = NStr("en = 'Balance of payables, advance payments, and overdue debts'; ru = 'Остатки по кредиторской задолженности, авансовым платежам и просроченной задолженности';pl = 'Saldo zobowiązań, zaliczek i przeterminowanych długów';es_ES = 'Saldo de las cuentas a pagar, pagos anticipados y deudas vencidas';es_CO = 'Saldo de las cuentas a pagar, pagos anticipados y deudas vencidas';tr = 'Borçlar, Avans ödemeler ve vadesi geçmiş borçlar bakiyesi';it = 'Saldo dei debiti, anticipi e i debiti scaduti';de = 'Saldo aus Verbindlichkeiten, Vorauszahlungen und überfälligen Schulden'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsPayable, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Opening balance, purchases, payments, and closing balance, separated to credit and advance payments'; ru = 'В отчете отображаются сведения о расчетах организации с поставщиками, включая заказы и договоры, в рамках которых заключались сделки между организацией и контрагентами.';pl = 'Saldo początkowe, zakup, płatności oraz saldo końcowe, rozdzielone na płatności kredytowe i zaliczkowe';es_ES = 'Saldo de apertura, compras, pagos y saldo de cierre, separados para el crédito y los pagos anticipados';es_CO = 'Saldo de apertura, compras, pagos y saldo de cierre, separados para el crédito y los pagos anticipados';tr = 'Kredi ve avans ödemelerine ayrılmış açılış bakiyesi, satın almalar, ödemeler ve kapanış bakiyesi';it = 'Saldo di apertura, acquisti, pagamenti, e saldo di chiusura, separati da crediti e pagamenti anticipati';de = 'Anfangssaldo, Einkäufe, Zahlungen und Abschlusssaldo getrennt nach Haben und Vorauszahlungen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsPayable, "BalanceInCurrency");
	OptionSettings.Details = NStr("en = 'Balance of payables, advance payments, and overdue debts'; ru = 'Остатки по кредиторской задолженности, авансовым платежам и просроченной задолженности';pl = 'Saldo zobowiązań, zaliczek i przeterminowanych długów';es_ES = 'Saldo de las cuentas a pagar, pagos anticipados y deudas vencidas';es_CO = 'Saldo de las cuentas a pagar, pagos anticipados y deudas vencidas';tr = 'Borçlar, Avans ödemeler ve vadesi geçmiş borçlar bakiyesi';it = 'Saldo dei debiti, anticipi e i debiti scaduti';de = 'Saldo aus Verbindlichkeiten, Vorauszahlungen und überfälligen Schulden'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsPayable, "StatementZeroInvoice");
	OptionSettings.Details = NStr("en = 'Opening balance, purchases, payments, advances paid, advances cleared, and closing balance including zero invoices'; ru = 'Начальный остаток, закупки, выплаченные авансы, зачтенные авансы и конечный остаток, включая нулевые инвойсы';pl = 'Saldo początkowe, zakupy, płatności, opłacone zaliczki, rozliczone zaliczki i saldo końcowew tym faktury zerowe';es_ES = 'Saldo inicial, compras, pagos, anticipos pagados, anticipos compensados y saldo final que incluye facturas con importe cero';es_CO = 'Saldo inicial, compras, pagos, anticipos pagados, anticipos compensados y saldo final que incluye facturas con importe cero';tr = 'Sıfır bedelli fatura içeren açılış bakiyesi, satın almalar, ödemeler, ödenen avanslar, temizlenen avanslar ve kapanış bakiyesi';it = 'Saldo iniziale, acquisti, pagamenti, pagamenti anticipati pagati, pagamenti anticipati liquidati e bilancio di chiusura incluse Fattura a zero';de = 'Anfangssaldo, Einkäufe, Zahlungen, geleistete Vorauszahlungen, verrechnete Vorauszahlungen und Abschlusssaldo einschließlich Nullrechnungen'");
	OptionSettings.VisibleByDefault = False;
	OptionSettings.FunctionalOptions.Add("UseZeroInvoicePurchases");
	
	// Accounts payable trend
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsPayableTrend, "DebtDynamics");
	OptionSettings.Details = NStr("en = 'Payables by periods displayed as a chart'; ru = 'Кредиторская задолженность по периодам в виде диаграммы.';pl = 'Zobowiązania według okresów wyświetlanych jako wykres';es_ES = 'Cuentas a pagar por períodos mostradas como diagrama';es_CO = 'Cuentas a pagar por períodos mostradas como diagrama';tr = 'Grafik olarak gösterilen dönemlere göre ödenecek borçlar';it = 'Debiti da pagare per periodo mostrati come grafico';de = 'Verbindlichkeiten nach Zeiträumen als Diagramm dargestellt'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsReceivableAging, "Default");
	OptionSettings.Details = NStr("en = 'Accounts receivable aging, and overdue debts according to payment terms'; ru = 'Отчет отображает суммы задолженностей контрагентов перед компанией с указанием сроков задолженности.';pl = 'Wiekowanie należności oraz długi przeterminowane zgodnie z warunkami płatności';es_ES = 'Antigüedad de las cuentas a cobrar y las deudas vencidas según los términos de pagos';es_CO = 'Antigüedad de las cuentas a cobrar y las deudas vencidas según los términos de pagos';tr = 'Alacak yaşlandırma ve ödeme koşullarına göre vadesi geçmiş borçlar';it = 'Età dei crediti esigibili, e debiti scaduti secondo i termini di pagamento';de = 'Ausgleich der Forderungen von Offenen Posten Debitoren und überfällige Schulden gemäß Zahlungsbedingungen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsReceivableAging, "InCurrency");
	OptionSettings.Details = NStr("en = 'Accounts receivable aging, and overdue debts according to payment terms'; ru = 'Отчет отображает суммы задолженностей контрагентов перед компанией с указанием сроков задолженности.';pl = 'Wiekowanie należności oraz długi przeterminowane zgodnie z warunkami płatności';es_ES = 'Antigüedad de las cuentas a cobrar y las deudas vencidas según los términos de pagos';es_CO = 'Antigüedad de las cuentas a cobrar y las deudas vencidas según los términos de pagos';tr = 'Alacak yaşlandırma ve ödeme koşullarına göre vadesi geçmiş borçlar';it = 'Età dei crediti esigibili, e debiti scaduti secondo i termini di pagamento';de = 'Ausgleich der Forderungen von Offenen Posten Debitoren und überfällige Schulden gemäß Zahlungsbedingungen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsPayableAging, "Default");
	OptionSettings.Details = NStr("en = 'Accounts payable aging, and overdue debts according to payment terms'; ru = 'Отчет отображает суммы задолженностей организации перед контрагентами с указанием сроков задолженности.';pl = 'Wiekowanie zobowiązań oraz przeterminowanych długów zgodnie z warunkami płatności';es_ES = 'Antigüedad de las cuentas por pagar y las deudas atrasadas según las condiciones de pago';es_CO = 'Antigüedad de las cuentas a pagar y las deudas vencidas según los términos de pagos';tr = 'Ödeme koşullarına göre borç yaşlandırma ve vadesi geçmiş borçlar';it = 'Età dei debiti da pagare, e debiti scaduti secondo i termini di pagamento';de = 'Ausgleich der Forderungen von Offenen Posten Kreditoren und überfällige Schulden gemäß Zahlungsbedingungen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AccountsPayableAging, "InCurrency");
	OptionSettings.Details = NStr("en = 'Accounts payable aging, and overdue debts according to payment terms'; ru = 'Отчет отображает суммы задолженностей организации перед контрагентами с указанием сроков задолженности.';pl = 'Wiekowanie zobowiązań oraz przeterminowanych długów zgodnie z warunkami płatności';es_ES = 'Antigüedad de las cuentas por pagar y las deudas atrasadas según las condiciones de pago';es_CO = 'Antigüedad de las cuentas a pagar y las deudas vencidas según los términos de pagos';tr = 'Ödeme koşullarına göre borç yaşlandırma ve vadesi geçmiş borçlar';it = 'Età dei debiti da pagare, e debiti scaduti secondo i termini di pagamento';de = 'Ausgleich der Forderungen von Offenen Posten Kreditoren und überfällige Schulden gemäß Zahlungsbedingungen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesOrdersTrend, "Default");
	OptionSettings.Details = NStr("en = 'Payment info, availability and supply status of goods ordered by customers'; ru = 'Отчет позволяет проанализировать выполнение Заказов покупателей по суммам и количеству.';pl = 'Informacje o płatności, dostępność i status dostawy towarów zamówionych przez nabywców';es_ES = 'Información de pagos, disponibilidad y el estado de suministro de las mercancías pedidas por los clientes';es_CO = 'Información de pagos, disponibilidad y el estado de suministro de las mercancías pedidas por los clientes';tr = 'Müşteriler tarafından sipariş edilen malların ödeme bilgileri, kullanılabilirliği ve tedarik durumu';it = 'Informazioni di pagamento, la disponibilità e il rifornimento della merce ordinata dai clienti';de = 'Zahlungsinformationen, Verfügbarkeit und Lieferstatus der von Kunden bestellten Waren'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.PurchaseOrdersOverview, "Default");
	OptionSettings.Details = NStr("en = 'Payment info and supply status of goods ordered to suppliers'; ru = 'Отчет позволяет проанализировать выполнение Заказов поставщикам по суммам и количеству.';pl = 'Informacje o płatności i status dostawy towarów, zamówionych u dostawców';es_ES = 'Información de pagos y el estado de suministro de las mercancías pedidas para los proveedores';es_CO = 'Información de pagos y el estado de suministro de las mercancías pedidas para los proveedores';tr = 'Tedarikçilere sipariş edilen malların ödeme bilgisi ve tedarik durumu';it = 'Informazioni di pagamento e stato di rifornimento delle merci ordinate ai fornitori';de = 'Zahlungsinformationen und Lieferstatus der bestellten Waren an Lieferanten'");
	
	// begin Drive.FullVersion
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.EmployeePerformanceReport, "Default");
	OptionSettings.Details = NStr("en = 'The report is designed to perform variance analysis of technological operations performed by employees within the job sheet'; ru = 'Отчет предназначен для проведения план-фактного анализа технологических операций, выполняемых сотрудниками в рамках сдельных нарядов.';pl = 'Raport służy do analizy wariancji operacji technologicznych, wykonywanych przez pracowników w ramach karty pracy';es_ES = 'El informe está diseñado para realizar el análisis de la varianza de operaciones tecnológicas realizadas por empleados dentro de la hoja de tareas';es_CO = 'El informe está diseñado para realizar el análisis de la varianza de operaciones tecnológicas realizadas por empleados dentro de la hoja de tareas';tr = 'Rapor, çalışanlar tarafından gerçekleştirilen teknolojik işlemlerin sapma analizini yapmak üzere tasarlanmıştır.';it = 'Il report è stato progettato per eseguire l''analisi delle variazioni delle operazioni tecnologiche svolte dai dipendenti all''interno del foglio di lavoro';de = 'Der Bericht wurde entwickelt, um eine Abweichungsanalyse von technologischen Operationen durchzuführen, die von Mitarbeitern innerhalb des Arbeitsblatts durchgeführt werden'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CostOfGoodsManufactured, "Full");
	OptionSettings.Details = NStr("en = 'Actual cost of goods manufactured, by cost items'; ru = 'Фактическая себестоимость произведенных товаров по номенклатуре.';pl = 'Koszt rzeczywisty wytworzonych towarów, według pozycji kosztów własnych';es_ES = 'Costo actual de los productos fabricados por unidades de costo';es_CO = 'Costo actual de los productos fabricados por unidades de costo';tr = 'Maliyet kalemlerine göre üretilen malların gerçek maliyeti';it = 'Costo effettivo dei beni prodotti per voce di costo';de = 'Selbstkosten der Warenherstellung, nach Kostenbestandteilen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CostOfGoodsManufactured, "Default");
	OptionSettings.Details = NStr("en = 'Actual cost of goods manufactured'; ru = 'Фактическая себестоимость выпуска';pl = 'Koszt rzeczywisty wyprodukowanych towarów';es_ES = 'Coste real de mercancías fabricadas';es_CO = 'Coste real de mercancías fabricadas';tr = 'Üretilen malların gerçek maliyeti';it = 'Costo effettivo della merce prodotta';de = 'Aktuelle Herstellselbstkosten'");
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		OptionSettings.SearchSettings.FieldDescriptions = NStr(
			"en = 'Cost item
			|Quantity produced
			|Amount
			|Unit cost
			|Finished product
			|Finished product unit'; 
			|ru = 'Элемент затрат
			|Количество продукции
			|Сумма
			|Себестоимость единицы
			|Готовая продукция
			|Единица измерения готовой продукции';
			|pl = 'Pozycja kosztów
			|Ilość produkcji
			|Kwota
			|Koszt własny jednostki
			|Gotowy produkt
			|J.m. gotowego produktu';
			|es_ES = 'Artículo del coste
			|Cantidad producida
			|Importe
			|Coste de la unidad
			|Producto terminado
			|Unidad del producto terminado';
			|es_CO = 'Artículo del coste
			|Cantidad producida
			|Importe
			|Coste de la unidad
			|Producto terminado
			|Unidad del producto terminado';
			|tr = 'Maliyet kalemi
			|Üretilen miktar
			|Tutar
			|Birim maliyeti
			|Nihai ürün
			|Nihai ürün birimi';
			|it = 'Voce di costo
			|Quantità prodotta
			|Importo
			|Costo dell''unità
			|Articolo finito
			|Unità articolo finito';
			|de = 'Kostenposition
			|Menge produziert
			|Menge
			|Selbstpreis pro Einheit
			|Fertigprodukte
			|Fertigprodukteinheit'");
	EndIf;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.DirectMaterialVariance, "Default");
	OptionSettings.Details = NStr("en = 'Difference between the standard cost of materials resulting from production operations and the actual costs incurred'; ru = 'Разница между стандартной себестоимостью сырья и материалов, полученных при производственных операциях, и фактической себестоимостью.';pl = 'Różnica między kosztem standardowym materiałów wynikającym z działań produkcyjnych i poniesionym kosztem rzeczywistym';es_ES = 'La diferencia entre el coste estándar de los materiales resultantes de las operaciones de producción y los costes reales incurridos';es_CO = 'La diferencia entre el coste estándar de los materiales resultantes de las operaciones de producción y los costes reales incurridos';tr = 'Üretim işlemlerinden kaynaklanan standart malzeme maliyeti ile gerçekleşen gerçek maliyetler arasındaki fark';it = 'Differenza tra il costo di materiali standard risultante dalle operazioni di produzione e i costi effettivi verificatisi';de = 'Unterschied zwischen den Standardkosten der Materialien aus Produktionsoperationen und den angefallenen Selbstkosten'");
	// end Drive.FullVersion
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockSummary, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, receipt, consumption, closing balance by products and warehouses'; ru = 'Начальный остаток, поступление, расход, конечный остаток по номенклатуре и складам.';pl = 'Saldo początkowe, paragon, zużycie, saldo końcowe produktów i magazynów';es_ES = 'Saldo inicial, recepción, consumo, saldo de cierre por productos y almacén';es_CO = 'Saldo inicial, recepción, consumo, saldo de cierre por productos y almacén';tr = 'Ürün ve depolara göre açılış bakiyesi, alınan, tüketim, kapanış bakiyesi';it = 'Saldo di apertura, ricevimenti, consumi, saldo di chiusura per articoli e magazzini';de = 'Anfangssaldo, Eingang, Verbrauch, Abschlusssaldo nach Produkten und Lagern'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockSummary, "Balance");
	OptionSettings.Details = NStr("en = 'Stock balance by products and warehouses'; ru = 'Остатки товаров по номенклатуре и складам';pl = 'Stan magazynowy według produktów i magazynów';es_ES = 'Saldo de existencias por productos y almacén';es_CO = 'Saldo de existencias por productos y almacén';tr = 'Ürünlere ve ambarlara göre stok bakiyesi';it = 'Saldo delle scorte per articolo e magazzini';de = 'Bestandsmenge nach Produkten und Lagern'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockSummary, "StatementByStorageBins");
	OptionSettings.Details = NStr("en = 'Opening balance, receipt, consumption, closing balance by products, warehouses and storage bins'; ru = 'Начальный остаток, поступление, расход, конечный остаток по номенклатуре, складам и складским ячейкам.';pl = 'Saldo początkowe, paragon, konsumpcja, saldo końcowe według produktów, magazynów i komórek magazynowych';es_ES = 'Saldo inicial, recepción, consumo, saldo de cierre por productos, almacenes y depósitos de almacenamiento';es_CO = 'Saldo inicial, recepción, consumo, saldo de cierre por productos, almacenes y depósitos de almacenamiento';tr = 'Ürünlere, ambarlara ve depolara göre açılış bakiyesi, alınan, tüketim ve kapanış bakiyesi';it = 'Saldo iniziale, ricevuta, consumo, bilancio di chiusura per articoli, magazzini e contenitori di magazzini';de = 'Anfangssaldo, Eingang, Verbrauch, Abschlusssaldo nach Produkten, Lagern und Lagerplätzen'");
	OptionSettings.FunctionalOptions.Add("UseStorageBins");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockSummary, "StatementByBatchNumbers");
	OptionSettings.Details = NStr("en = 'Opening balance, receipt, consumption, closing balance by products, warehouses and batch numbers'; ru = 'Начальный остаток, приход, потребление, конечный остаток в разрезе номенклатуры, складов и партий';pl = 'Saldo początkowe, paragon, konsumpcja, saldo końcowe według produktów, magazynów i numerów partii';es_ES = 'Saldo inicial, recepción, consumo, saldo de cierre por productos, almacenes y números del lote';es_CO = 'Saldo inicial, recepción, consumo, saldo de cierre por productos, almacenes y números del lote';tr = 'Ürünlere, ambarlara ve parti numaralarına göre açılış bakiyesi, giriş, tüketim ve kapanış bakiyesi';it = 'Saldo iniziale, ricevuta, consumo, bilancio di chiusura per prodotto, magazzino e numero di lotto';de = 'Anfangssaldo, Eingang, Verbrauch, Abschlusssaldo nach Produkten, Lagern und Chargennummern'");
	OptionSettings.FunctionalOptions.Add("UseBatches");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.EmployeesLists, "EmployeesList");
	OptionSettings.Details = NStr("en = 'Employee, position, and FTE'; ru = 'Сотрудник, должность и количество ставок.';pl = 'Pracownik, stanowisko i etat';es_ES = 'Empleado, posición y ETC';es_CO = 'Empleado, posición y ETC';tr = 'Çalışan, pozisyon ve Tam süreli eşdeğer';it = 'Dipendente, posizione, e FTE';de = 'Mitarbeiter, Position und FTE'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.EmployeesLists, "EarningsPlan");
	OptionSettings.Details = NStr("en = 'Employees compensation plan'; ru = 'Плановые начисления сотрудникам.';pl = 'Naliczenia i potrącenia pracowników';es_ES = 'Plan de las compensaciones de empleados';es_CO = 'Plan de las compensaciones de empleados';tr = 'Çalışanın tazminat planı';it = 'Piano di compensazione dipendenti';de = 'Mitarbeitervergütungsplan'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.EmployeesLists, "PassportData");
	OptionSettings.Details = NStr("en = 'Employees identity document data'; ru = 'Паспортные данные сотрудников.';pl = 'Dane dokumentów tożsamości pracowników';es_ES = 'Datos del documento de identificación del empleado';es_CO = 'Datos del documento de identificación del empleado';tr = 'Çalışanın kimlik belgesi verileri';it = 'Dati documenti di identità dipendenti';de = 'Daten zu Identitätsdokumenten der Mitarbeiter'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.EmployeesLists, "ContactInformation");
	OptionSettings.Details = NStr("en = 'Employees, postal address, actual address and phone number'; ru = 'Сотрудники, почтовые адреса, фактические адреса и номера телефонов.';pl = 'Pracownicy, adres pocztowy, rzeczywisty adres i numer telefonu';es_ES = 'Empleados, dirección postal, dirección actual y número de teléfono';es_CO = 'Empleados, dirección postal, dirección actual y número de teléfono';tr = 'Çalışanlar, posta adresi, gerçek adres ve telefon numarası';it = 'Dipendenti, indirizzo di posta, indirizzo effettivo e numero di telefono';de = 'Mitarbeiter, Postanschrift, aktuelle Adresse und Telefonnummer'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.POSSummary, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, increase, decrease, closing balance of retail value and cost (for Retail Inventory Method)'; ru = 'Отчет предназначен для анализа продаж в розничной точке с суммовым учетом';pl = 'Saldo początkowe, zwiększenie, zmniejszenie, saldo końcowe wartości detalicznej i kosztów własnych (dla Metody inwentaryzacji w sprzedaży detalicznej)';es_ES = 'Saldo de apertura, aumento, disminución, saldo de cierre del valor de la venta al por menor y el coste (para el Método de Inventario de la Venta al por menor)';es_CO = 'Saldo de apertura, aumento, disminución, saldo de cierre del valor de la venta al por menor y el coste (para el Método de Inventario de la Venta al por menor)';tr = 'Perakende değer ve maliyetinin açılış bakiyesi, artış, azalma, kapanış bakiyesi (Perakende Stok Yöntemi için)';it = 'Saldo di apertura, aumento, diminuzione, il saldo di chiusura del valore di vendita e il costo (per il Retail Metodo dell''Inventario)';de = 'Anfangssaldo, Erhöhung, Abnahme, Abschlusssaldo des Einzelhandelswerts und der Anschaffungskosten (für Retail Inventory Method)'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.POSSummary, "Balance");
	OptionSettings.Details = NStr("en = 'Retail value and cost of goods (for Retail Inventory Method)'; ru = 'Отчет предназначен для анализа состояния продаж в розничной точке с суммовым учетом';pl = 'Wartość detaliczna i koszty własne towarów (dla Metody inwentaryzacji w sprzedaży detalicznej)';es_ES = 'Valor de la venta minorista y el coste de mercancías (Método de Inventario de la Venta al por menor)';es_CO = 'Valor de la venta minorista y el coste de mercancías (Método de Inventario de la Venta al por menor)';tr = 'Perakende değeri ve mal maliyeti (Envanter Perakende Yöntemi için)';it = 'Valore di vendita e il costo delle merci (per la vendita al Dettaglio Metodo dell''Inventario)';de = 'Einzelhandelswert und Warenkosten (für Inventurmethode (Einzelhandel))'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.POSSummary, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Opening balance, increase, decrease, closing balance of retail value (for Retail Inventory Method)'; ru = 'Отчет предназначен для анализа состояния продаж в розничной точке с суммовым учетом в валюте.';pl = 'Saldo początkowe, wzrost, spadek, saldo końcowe wartości detalicznej (za pomocą Metoda inwentaryzacji w sprzedaży detalicznej)';es_ES = 'Saldo de apertura, aumento, disminución, saldo de cierre del valor de la venta minorista (para el Método de Inventario de la Venta al por menor)';es_CO = 'Saldo de apertura, aumento, disminución, saldo de cierre del valor de la venta minorista (para el Método de Inventario de la Venta al por menor)';tr = 'Açılış bakiyesi, artış, azalma, perakende değeri kapanış bakiyesi (Envanter Perakende Yöntemi için)';it = 'Saldo di apertura, aumento, diminuzione, il saldo di chiusura del valore al dettaglio (Retail Metodo dell''Inventario)';de = 'Anfangssaldo, Erhöhung, Abnahme, Abschlusssaldo des Einzelhandelswerts (für Inventurmethode (Einzelhandel))'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.POSSummary, "BalanceInCurrency");
	OptionSettings.Details = NStr("en = 'Retail value of goods (for Retail Inventory Method)'; ru = 'Отчет предназначен для анализа состояния задолженности розницы с суммовым учетом в валюте';pl = 'Wartość detaliczna towarów (dla Metody inwentaryzacji w sprzedaży detalicznej)';es_ES = 'Valor de la venta minorista de mercancías (para el Método de Inventario de la Venta al por menor)';es_CO = 'Valor de la venta minorista de mercancías (para el Método de Inventario de la Venta al por menor)';tr = 'Malların perakende değeri (Envanter Perakende Yöntemi için)';it = 'Valore al dettaglio di beni (per metodo di vendita scorte al dettaglio)';de = 'Einzelhandelswert von Waren (für Retail Inventory Method)'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CostOfSales, "Statement");
	OptionSettings.Details = NStr("en = 'Cost of sales refers to the direct costs attributable to the goods sold or supply of services'; ru = 'Себестоимость продаж отражает прямые затраты, применимые к продаже товаров или предоставлению услуг.';pl = 'Koszt własny sprzedaży ma stosunek do bezpośrednich kosztów związanych ze sprzedanymi towarami lub świadczeniem usług';es_ES = 'El coste de ventas se refiere a los costes directos atribuibles a los bienes vendidos o a la prestación de servicios';es_CO = 'El coste de ventas se refiere a los costes directos atribuibles a los bienes vendidos o a la prestación de servicios';tr = 'Satışların maliyeti, satılan mallara veya hizmet arzına atfedilebilen doğrudan maliyetlerdir.';it = 'Il costo di vendita si riferisce ai costi diretti attribuibili alla merce venduta o al servizio erogato';de = 'Die Umsatzkosten umfassen die direkten Kosten, die den verkauften Waren oder Dienstleistungen zugeordnet werden können'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CostOfSalesBudget, "Default");
	OptionSettings.Details = NStr("en = 'Report presents financial result forecast of the selected scenario'; ru = 'В отчет выводятся сведения о прогнозе финансового результата по указанному сценарию.';pl = 'Sprawozdanie przedstawia prognozę wyniku finansowego według wybranego scenariusza';es_ES = 'Informe presenta el pronóstico de resultados financieros del escenario seleccionado';es_CO = 'Informe presenta el pronóstico de resultados financieros del escenario seleccionado';tr = 'Rapor seçilen senaryonun finansal sonuç tahminini sunar';it = 'Il report mostra le informazioni sulla previsione del risultato finanziario secondo lo scenario specificato';de = 'Der Bericht enthält die Finanzergebnisprognose des ausgewählten Szenarios'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CostOfSalesBudget, "Planfact analysis");
	OptionSettings.Details = NStr("en = 'The report compares forecast and actual financial results'; ru = 'В отчете сравнивается прогнозный и фактический финансовый результат.';pl = 'Raport porównuje prognozowane i rzeczywiste wyniki finansowe';es_ES = 'El informe compara el pronóstico y los resultados financieros reales';es_CO = 'El informe compara el pronóstico y los resultados financieros reales';tr = 'Rapor tahmini ve fiili finansal sonuçları karşılaştırır';it = 'Il report confronta i risultati finanziari di pianificazione ed effettivi';de = 'Der Bericht vergleicht die prognostizierten und tatsächlichen finanziellen Ergebnisse'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.HeadcountVariance, "Default");
	OptionSettings.Details = NStr("en = 'Headcount budget vs actual'; ru = 'Штатный и фактический бюджет.';pl = 'Zatrudnienie a rzeczywisty budżet';es_ES = 'Saldo personal vs actual';es_CO = 'Saldo personal vs actual';tr = 'Gerçek bütçeye karşılık bordrolu çalışan sayısının bütçesi';it = 'Budget del organico vs effettivo';de = 'Personalbudget vs. Ist-Budget'");
	
	// DiscountCards
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesWithCardBasedDiscounts, "SalesWithCardBasedDiscounts");
	OptionSettings.Description = NStr("en = 'Discounts granted by discount cards'; ru = 'Скидки по дисконтным картам';pl = 'Rabaty udzielane przez karty rabatowe';es_ES = 'Descuentos otorgados por tarjetas de descuento';es_CO = 'Descuentos otorgados por tarjetas de descuento';tr = 'İndirim kartına verilen indirimler';it = 'Sconti concessi attraverso carte sconto';de = 'Ermäßigungen durch Rabattkarten'");	
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesWithCardBasedDiscounts, "SalesByDiscountCard");
	OptionSettings.Details = NStr("en = 'The report is called from the ""Discount cards"" data processor and displays data on sales by discount cards for a certain period of time in monetary terms'; ru = 'Отчет вызывается из обработки ""Дисконтные карты"" и отображает сведения о продажах по дисконтной карте в суммовом выражении за определенный период времени';pl = 'Sprawozdanie jest wywoływane z procesora przetwarzania danych ""Karty rabatowe"" i wyświetla dane o sprzedaży przy użyciu kart rabatowych w określonym okresie czasu w kategoriach pieniężnych';es_ES = 'El informe se ha llamado desde el procesador de datos ""Tarjetas de descuento"" y visualiza los datos sobre descuentos por tarjetas de descuentos para un cierto período de tiempo en los términos monetarios';es_CO = 'El informe se ha llamado desde el procesador de datos ""Tarjetas de descuento"" y visualiza los datos sobre descuentos por tarjetas de descuentos para un cierto período de tiempo en los términos monetarios';tr = 'Rapor, ""İndirim Kartları"" veri işlemcisinden çağrılır ve mali koşullarda belirli bir süre için satışa ilişkin verileri indirim kartları ile gösterir.';it = 'Il report viene richiamato dall''elaborazione ""Carte sconto"" e visualizza le informazioni di vendita sulla carta sconto nell''espressione di somma per un certo periodo di tempo';de = 'Der Bericht wird von dem Datenprozessor ""Rabattkarten"" aufgerufen und zeigt Daten über den Verkauf durch Rabattkarten für einen bestimmten Zeitraum in finanzieller Hinsicht an'");	
	OptionSettings.Enabled = False;
	OptionSettings.VisibleByDefault = False;
	// End DiscountCards
	
	// AutomaticDiscounts
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.AutomaticDiscountSales, "AutomaticDiscounts");
	OptionSettings.Details = NStr("en = 'Automatic discounts granted'; ru = 'Автоматические скидки.';pl = 'Automatycznie zastosowane rabaty';es_ES = 'Descuentos automáticos otorgados';es_CO = 'Descuentos automáticos otorgados';tr = 'Sağlanan otomatik indirimler';it = 'Sconti automatici concessi';de = 'Automatische Rabatte gewährt'");	
	// End AutomaticDiscounts
	
	// Miscellaneous payable
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.MiscellaneousPayableStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, debits, credits, closing balance of miscellaneous payable'; ru = 'Начальный остаток, приходы, расходы, конечный остаток прочих платежей.';pl = 'Saldo początkowe. zobowiązania, należności, saldo końcowe różnych płatności';es_ES = 'Saldo inicial, deudas, haberes, saldo final por varias cuentas a pagar';es_CO = 'Saldo inicial, deudas, haberes, saldo final por varias cuentas a pagar';tr = 'Çeşitli borçların açılış bakiyesi, borçlar, krediler, kapanış bakiyesi';it = 'Saldo di apertura, debiti, crediti, saldo di chiusura di debiti vari da pagare';de = 'Anfangssaldo, Soll, Haben, Abschlusssaldo der diversen Zahlungen gegenüber Dritten'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.MiscellaneousPayableStatement, "Balances");
	OptionSettings.Details = NStr("en = 'The balance of miscellaneous payable'; ru = 'Остаток прочих платежей';pl = 'Saldo różnych płatności';es_ES = 'Saldo de varias cuentas a pagar';es_CO = 'Saldo de varias cuentas a pagar';tr = 'Ödenecek çeşitli borçların bakiyesi';it = 'Il saldo di debiti vari da pagare';de = 'Der Saldo aus diversen Zahlungen'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.MiscellaneousPayableStatement, "StatementInCurrency");
	OptionSettings.Details = NStr("en = 'Opening balance, debits, credits, closing balance of miscellaneous payable'; ru = 'Начальный остаток, приходы, расходы, конечный остаток прочих платежей.';pl = 'Saldo początkowe. zobowiązania, należności, saldo końcowe różnych płatności';es_ES = 'Saldo inicial, deudas, haberes, saldo final por varias cuentas a pagar';es_CO = 'Saldo inicial, deudas, haberes, saldo final por varias cuentas a pagar';tr = 'Çeşitli borçların açılış bakiyesi, borçlar, krediler, kapanış bakiyesi';it = 'Saldo di apertura, debiti, crediti, saldo di chiusura di debiti vari da pagare';de = 'Anfangssaldo, Soll, Haben, Abschlusssaldo der diversen Zahlungen gegenüber Dritten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.MiscellaneousPayableStatement, "BalancesInCurrency");
	OptionSettings.Details = NStr("en = 'The balance of miscellaneous payable'; ru = 'Остаток прочих платежей';pl = 'Saldo różnych płatności';es_ES = 'Saldo de varias cuentas a pagar';es_CO = 'Saldo de varias cuentas a pagar';tr = 'Ödenecek çeşitli borçların bakiyesi';it = 'Il saldo di debiti vari da pagare';de = 'Der Saldo aus diversen Zahlungen'");
	OptionSettings.VisibleByDefault = False;
	// End miscellaneous payable
	
	// Serial numbers
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SerialNumbersTracking, "Balance");
	OptionSettings.Details = NStr("en = 'The report shows the rest of the goods in the warehouses with the details by serial number.'; ru = 'Отчет отображает остаток товаров на складах с детализацией по серийным номерам.';pl = 'Sprawozdanie odzwierciedla pozostałą część towarów w magazynach z detalizacją według numeru seryjnego.';es_ES = 'El informe muestra el resto de las mercancías en los almacenes con los detalles por el número de serie.';es_CO = 'El informe muestra el resto de las mercancías en los almacenes con los detalles por el número de serie.';tr = 'Rapor, depolardaki malların geri kalanını seri numarasına göre detaylarıyla göstermektedir.';it = 'Il report mostra le rimanenze di merci nei magazzini con i dettagli per numero di serie.';de = 'Der Bericht zeigt den Rest der Waren in den Lagern mit den Details nach Seriennummer.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SerialNumbersTracking, "Statement");
	OptionSettings.Details = NStr("en = 'The report shows a list of goods movement in warehouses with detailed information on serial numbers.'; ru = 'Отчет отображает ведомость движения товаров на складах с детализацией по серийным номерам.';pl = 'Sprawozdanie odzwierciedla listę przemieszczania towarów w magazynach ze szczegółowymi informacjami na temat numerów seryjnych.';es_ES = 'El informe muestra una lista del movimiento de mercancías en los almacenes con la información detallada sobre los números de serie.';es_CO = 'El informe muestra una lista del movimiento de mercancías en los almacenes con la información detallada sobre los números de serie.';tr = 'Rapor, seri numaralar hakkında detaylı bilgi içeren depolardaki mal hareketlerinin bir listesini göstermektedir.';it = 'Il report mostra un elenco di movimenti merci nei magazzini con informazioni dettagliate sui numeri di serie.';de = 'Der Bericht zeigt eine Liste der Warenbewegungen in Lagern mit detaillierten Informationen zu Seriennummern.'");
	// End Serial numbers
	
	// Loans
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.LoanAccountStatement, "LoansToEmployees");
	OptionSettings.Details = NStr("en = 'Opening balance, accruals, repayments, closing balance of loans lent'; ru = 'Начальный остаток, начисления, погашения, конечный остаток выданных займов.';pl = 'Saldo początkowe, naliczenia, spłaty, saldo końcowe pożyczek zaciągniętych';es_ES = 'Saldo inicial, acumulaciones, reembolsos, saldo final de préstamos concedidos';es_CO = 'Saldo inicial, devengo, amortizaciones, saldo final de préstamos';tr = 'Verilen kredilerin açılış bakiyesi, tahakkuklar, geri ödemeler, kapanış bakiyesi';it = 'Saldo di apertura, maturato, rimborsi, saldo di chiusura di prestiti dati';de = 'Anfangssaldo, Rückstellungen, Rückzahlungen, Abschlusssaldo der ausgeliehenen Darlehen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.LoanAccountStatement, "LoansReceived");
	OptionSettings.Details = NStr("en = 'Opening balance, accruals, repayments, closing balance of loans borrowed'; ru = 'Начальный остаток, начисления, погашения, конечный остаток полученных займов.';pl = 'Saldo początkowe, naliczenia, spłaty, saldo końcowe otrzymanych pożyczek';es_ES = 'Saldo inicial, acumulaciones, reembolsos, saldo final de préstamos prestados';es_CO = 'Saldo inicial, devengo, amortizaciones, saldo final de préstamos prestados';tr = 'Alınan kredilerin açılış bakiyesi, tahakkuklar, geri ödemeler, kapanış bakiyesi';it = 'Saldo di apertura, maturato, rimborsi, saldo di chiusura di prestiti presi';de = 'Anfangssaldo, Rückstellungen, Rückzahlungen, Abschlusssaldo der aufgenommenen Darlehen'");
	// End Loans
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProductSegmentContent, "Default");
	OptionSettings.Details = NStr("en = 'The report shows the current counterparty segment.'; ru = 'Отчет отображает текущий состав сегмента контрагентов.';pl = 'Sprawozdanie odzwierciedla bieżący segment kontrahenta.';es_ES = 'El informe muestra el segmento de la contraparte actual.';es_CO = 'El informe muestra el segmento de la contraparte actual.';tr = 'Rapor mevcut cari hesap segmentini gösterir.';it = 'Il report mostra il segmento corrente della controparte';de = 'Der Bericht zeigt das aktuelle Geschäftspartnersegment.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CounterpartySegmentContent, "SegmentContentContext");
	OptionSettings.Details = NStr("en = 'The report shows the current counterparty segment.'; ru = 'Отчет отображает текущий состав сегмента контрагентов.';pl = 'Sprawozdanie odzwierciedla bieżący segment kontrahenta.';es_ES = 'El informe muestra el segmento de la contraparte actual.';es_CO = 'El informe muestra el segmento de la contraparte actual.';tr = 'Rapor mevcut cari hesap segmentini gösterir.';it = 'Il report mostra il segmento corrente della controparte';de = 'Der Bericht zeigt das aktuelle Geschäftspartnersegment.'");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProductSegmentContent, "Default");
	OptionSettings.Details = NStr("en = 'The report shows the current product segment.'; ru = 'Отчет отображает текущий состав сегмента номенклатуры.';pl = 'Raport pokazuje bieżący segment produktu.';es_ES = 'El informe muestra el segmento del producto actual.';es_CO = 'El informe muestra el segmento del producto actual.';tr = 'Rapor mevcut ürün segmentini gösterir.';it = 'Il report mostra il segmento articolo attuale.';de = 'Der Bericht zeigt das aktuelle Produktsegment.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProductSegmentContent, "ProductSegmentContentContext");
	OptionSettings.Enabled = False;
	OptionSettings.Placement.Clear();
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.GoodsInvoicedNotShipped, "Default");
	OptionSettings.Details = NStr("en = 'Goods invoiced, but not yet shipped by goods issue documents'; ru = 'Товары отраженные, но не отправленные с помощью документа ""Отпуск товаров"".';pl = 'Towary zafakturowane, ale jeszcze nie wysłane przez dokumenty wydanie zewnętrzne';es_ES = 'Los productos han sido facturados pero todavía no se han enviados por la expedición de documentos';es_CO = 'Los productos han sido facturados pero todavía no se han enviados por la expedición de documentos';tr = 'Faturalanmış, ancak henüz ambar çıkışı belgeleriyle sevk edilmemiş mallar';it = 'Merci fatturate, ma non ancora spedite per documenti di spedizione';de = 'Fakturierte, aber noch nicht durch Warenausgangsbelege gelieferte Waren'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.GoodsShippedNotInvoiced, "Default");
	OptionSettings.Details = NStr("en = 'Goods shipped by Goods issue documents, but not yet invoiced'; ru = 'Товары, отгруженные по документу ""Отпуск товаров"", но по которым не оформлен инвойс.';pl = 'Towar wysłany przez dokumenty Wydanie zewnętrzne, ale jeszcze nie zafakturowany';es_ES = 'Mercancías enviadas por los documentos de emisión de Mercancías, pero aún no facturadas';es_CO = 'Mercancías enviadas por los documentos de emisión de Mercancías, pero aún no facturadas';tr = 'Ambar çıkışı belgeleriyle gönderilmiş, ancak henüz faturalanmamış mallar';it = 'Merci spedite per Spedizioni Merce, ma non ancora fatturate';de = 'Durch Warenausgangsbelege gelieferte aber noch nicht fakturierte Waren'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.StockStatementWithCostLayers, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, receipt, consumption, closing balance (FIFO)'; ru = 'Начальный остаток, поступление, расход, конечный остаток (FIFO)';pl = 'Saldo początkowe, paragon, zużycie, saldo końcowe (FIFO)';es_ES = 'Saldo inicial, recibo, consumación, saldo final (FIFO)';es_CO = 'Saldo inicial, recibo, consumación, saldo final (FIFO)';tr = 'Açılış bakiyesi, alınan, tüketim, kapanış bakiyesi (FIFO)';it = 'Saldo di apertura, ricevimenti, consumi, saldo di chiusura (FIFO)';de = 'Anfangssaldo, Eingang, Verbrauch, Abschlusssaldo (FIFO)'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.GoodsInvoicedNotReceived, "Default");
	OptionSettings.Details = NStr("en = 'Goods invoiced, but not yet received by Goods receipt documents'; ru = 'Отраженные, но не полученные с помощью документа ""Поступление товаров"" товары.';pl = 'Towary zafakturowane, ale jeszcze nie odebrane według dokumentów przyjęcia zewnętrznego';es_ES = 'Los productos han sido facturados pero todavía no se han recibidos por los documentos de Recepción de productos';es_CO = 'Los productos han sido facturados pero todavía no se han recibidos por los documentos de Recepción de productos';tr = 'Faturalanan ancak henüz Ambar girişi belgeleriyle alınmayan mallar';it = 'Merci fatturate, ma non ancora ricevute secondo documenti di ricezione merci';de = 'Fakturierte aber in Übereinstimmung mit den Wareneingangsbelegen nicht erhaltene Waren'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.GoodsReceivedNotInvoiced, "Default");
	OptionSettings.Details = NStr("en = 'Goods received by Goods receipt documents, but not yet invoiced'; ru = 'Номенклатура, полученная по документу ""Поступление товаров"", но по которой не оформлен инвойс.';pl = 'Towary otrzymane przez dokumenty Przyjęcia zewnętrznego, ale jeszcze nie zafakturowane';es_ES = 'Mercancías recibidad por los documentos de recibo de Mercancías, pero aún no facturadas';es_CO = 'Mercancías recibidad por los documentos de recibo de Mercancías, pero aún no facturadas';tr = 'Ambar girişi belgeleriyle alınan ancak henüz faturalandırılmayan mallar';it = 'Merci ricevute per Documento di Trasporto, ma non ancora fatturate';de = 'Noch nicht fakturierte aber nach Wareneingangsbelegen erhaltene Waren'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesPipeline, "Comparison");
	OptionSettings.Details = NStr("en = 'Campaign progress comparison chart as of different dates'; ru = 'Сравнительная диаграмма развития кампании на разные даты.';pl = 'Wykres porównania postępów kampanii na różne daty';es_ES = 'Diagrama de comparación de progresos de la campaña a partir de diferentes fechas';es_CO = 'Diagrama de comparación de progresos de la campaña a partir de diferentes fechas';tr = 'Farklı tarihlerden itibaren kampanya ilerleme karşılaştırma tablosu';it = 'Grafico confronto tra i progressi della campagna come date differenti';de = 'Diagramm zum Vergleich des Kampagnen-Fortschritts zu verschiedenen Terminen'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesPipeline, "BySalesReps");
	OptionSettings.Details = NStr("en = 'Campaign progress chart by sales representatives'; ru = 'Диаграмма развития кампании по торговым представительствам.';pl = 'Wykres postępów kampanii według przedstawicieli handlowych';es_ES = 'Diagrama de comparación de progresos de la campaña por ventas representativas';es_CO = 'Diagrama de comparación de progresos de la campaña por agente de ventas';tr = 'Satış temsilcileri tarafından yapılan kampanya ilerleme tablosu';it = 'Grafico avanzamento campagna secondo rappresentanti di vendita';de = 'Diagramm des Kampagnen-Fortschritts der Außendienstmitarbeiter'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.InvoicesValidForEPD, "InvoicesValidForEPD");
	OptionSettings.Details = NStr("en = 'Invoices valid for early payment discount'; ru = 'Инвойсы, доступные для скидки за досрочную оплату.';pl = 'Faktury, obowiązujące w przypadku skonto';es_ES = 'Facturas válidas para el descuento por pronto pago';es_CO = 'Facturas válidas para el descuento por pronto pago';tr = 'Erken ödeme indirimi için geçerli faturalar';it = 'Fatture valide per sconto da pagamento anticipato';de = 'Rechnungen, die für Skonto gelten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SalesFunnel, "SalesFunnel");
	OptionSettings.Details = NStr("en = 'The report shows the conversion rate from lead to repetitive sales'; ru = 'Отчет показывает коэффициент перехода из лидов в постоянные покупатели.';pl = 'Raport pokazuje współczynnik konwersji z leadu do sprzedaży powtarzanej';es_ES = 'El informe muestra la tasa de conversión del lead a las ventas repetitivas';es_CO = 'El informe muestra la tasa de conversión del lead a las ventas repetitivas';tr = 'Rapor, potansiyel satışlardan tekrarlayan satışlara dönüşüm oranını gösterir';it = 'Il report mostra il tasso di conversione da lead a vendita ripetitiva';de = 'Der Bericht zeigt die Konversionsrate von Lead zu Wiederholungsverkäufen.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CustomerAcquisitionChannels, "Default");
	OptionSettings.Details = NStr("en = 'The report analyzes acquisition channels by the number of leads and customers brought in'; ru = 'Отчет анализирует источники привлечения по количеству новых лидов и покупателей.';pl = 'Raport analizuje kanały pozyskiwania według ilości pozyskanych leadów i nabywców';es_ES = 'El informe analiza los canales de adquisición en función del número de clientes potenciales y de clientes atraídos.';es_CO = 'El informe analiza los canales de venta en función del número de leads y de clientes atraídos';tr = 'Rapor, satın alma kanallarını getirdiği müşteri sayısı ve müşteri sayısına göre analiz eder';it = 'Il report analizza i canali di acquisizione per numero di lead e clienti attirati';de = 'Der Bericht analysiert die Akquisitionskanäle nach der Anzahl der Leads und hinzugekommenen Kunden'");
	
	// begin Drive.FullVersion
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CostOfGoodsProduced, "Default");
	OptionSettings.Details = NStr("en = 'The details of Cost of goods produced'; ru = 'Расшифровка себестоимости выпуска.';pl = 'Szczegóły kosztów własnych produkcji';es_ES = 'Detalles del coste de las mercancías producidas';es_CO = 'Detalles del coste de las mercancías producidas';tr = 'Üretilen malların maliyetinin ayrıntıları';it = 'Dettagli del Costo delle merci prodotte';de = 'Details von hergestellten Warenkosten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.WorkInProgress, "WorkInProgress");
	OptionSettings.Details = NStr("en = 'The structure of Work-in-progress'; ru = 'Структура документа ""Незавершенное производство""';pl = 'Struktura Pracy w toku';es_ES = 'Estructura del Trabajo en progreso';es_CO = 'Estructura del Trabajo en progreso';tr = 'İşlem bitişinin yapısı';it = 'La struttura del Lavoro in corso';de = 'Die Struktur der Arbeit-in-Bearbeitung'");
	
	ReportSettings = ReportsOptions.ReportDetails(Settings, Metadata.Reports.ProductionOrderAvailableStock);
	ReportSettings.VisibleByDefault = False;
	ReportSettings.DefineFormSettings = True;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProductionOrderAvailableStock, "ProductionOrderAvailableStock");
	OptionSettings.Details = NStr("en = 'To monitor availability of components required to complete a certain Production order. For example, you can quickly check which and how many components are out of stock now.'; ru = 'Для контроля наличия компонентов, необходимых для выполнения определенного заказа на производство. Например, вы можете быстро проверить, каких компонентов и в каком количестве сейчас нет в наличии.';pl = 'Aby śledzić dostępność komponentów wymaganych do wykonania Zlecenia produkcyjnego. Na przykład, można szybko sprawdzić, jakich i ile komponentów nie ma w zapasach.';es_ES = 'Para controlar la disponibilidad de los componentes necesarios para finalizar una determinada orden de producción. Por ejemplo, puede comprobar rápidamente cuáles y cuántos componentes están agotados ahora.';es_CO = 'Para controlar la disponibilidad de los componentes necesarios para finalizar una determinada orden de producción. Por ejemplo, puede comprobar rápidamente cuáles y cuántos componentes están agotados ahora.';tr = 'Belirli bir Üretim emrini tamamlamak için gereken malzemelerin müsaitliğini kontrol etmek için. Örneğin, stokta şu anda hangi malzemeden kaç adet eksik olduğunu kolayca kontrol edebilirsiniz.';it = 'Monitorare la disponibilità di componenti richieste per completare un determinato Ordine di produzione. Ad esempio, è possibile verificare rapidamente quali e quante componenti non sono al momento disponibili.';de = 'Für Überprüfung der Verfügbarkeit der Komponenten erforderlich für Abschließen eines bestimmten Produktionsauftrags. Z. B., können Sie schnell überprüfen welche und wie viele Komponenten jetzt nicht vorrätig sind.'");
	OptionSettings.VisibleByDefault = False;
	
	// end Drive.FullVersion
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ThirdPartyPayments, "ThirdPartyPayments");
	OptionSettings.Details = NStr("en = 'Balance of third-party payments'; ru = 'Остаток по сторонним платежам.';pl = 'Saldo płatności strony trzeciej';es_ES = 'Saldo de pagos a terceros';es_CO = 'Saldo de pagos a terceros';tr = 'Üçüncü taraf ödemeler bakiyesi';it = 'Saldo dei pagamenti da terzi';de = 'Bilanz der Drittzahlungen'");
	
	// Subcontracting
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CostOfSubcontractorGoods, "Default");
	OptionSettings.Details = NStr("en = 'The details of Cost of goods produced by subcontractor'; ru = 'Описание себестоимости товаров, изготовленных переработчиком.';pl = 'Szczegóły dotyczące kosztów towarów wyprodukowanych przez podwykonawcę';es_ES = 'Detalles del coste de las mercancías producidas por el subcontratista';es_CO = 'Detalles del coste de las mercancías producidas por el subcontratista';tr = 'Alt yüklenici tarafından üretilen malların Maliyet ayrıntıları';it = 'I dettagli di Costo delle merci prodotte dal subfornitore';de = 'Die Details der Kosten der vom Subunternehmer hergestellten Waren'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SubcontractorOrderIssuedStatement, "FinishedProducts");
	OptionSettings.Details = NStr("en = 'Products ordered to subcontractors, received and expected from them.'; ru = 'Продукция, произведённая переработчиком: заказанная, полученная и ожидаемая.';pl = 'Produkty zamówione wykonawcom otrzymane, i oczekiwane od nich.';es_ES = 'Productos pedidos a los subcontratistas, recibidos y previstos.';es_CO = 'Productos pedidos a los subcontratistas, recibidos y previstos.';tr = 'Alt yüklenicilere sipariş verilen, teslim alınan ve onlardan beklenen ürünler.';it = 'Articoli ordinati presso i subfornitori, ricevuti e attesi da loro.';de = 'Produkte, die bei Subunternehmern bestellt, erhalten und von ihnen erwartet werden.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SubcontractorOrderIssuedStatement, "Components");
	OptionSettings.Details = NStr("en = 'Components transferred to subcontractors, consumed and returned by them.'; ru = 'Компоненты у переработчика: переданные, израсходованные и возвращенные.';pl = 'Komponenty przekazane do podwykonawców, zużyte i zwrócone przez nich.';es_ES = 'Componentes transferidos a los subcontratistas, consumidos y devueltos.';es_CO = 'Componentes transferidos a los subcontratistas, consumidos y devueltos.';tr = 'Alt yüklenicilere transfer edilen, tüketilen ve alt yüklenicilerden iade edilen malzemeler.';it = 'Componenti trasferite ai subfornitori, utilizzate e restituite da loro.';de = 'Komponenten, die an Subunternehmer übertragen, von diesen verbraucht und zurückgegeben werden.'");
	
	// begin Drive.FullVersion
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.CustomerProvidedInventoryStatement, "Default");
	OptionSettings.Details = NStr("en = 'Required, received, consumed, availability of components provided by customer.'; ru = 'Потребность, получено, расход, наличие компонентов, предоставленных покупателем.';pl = 'Zapotrzebowanie, otrzymano, zużyto, dostępność komponentów dostarczonych przez nabywcę.';es_ES = 'Requerido, recibido, consumido, disponibilidad de los componentes proporcionados por el cliente.';es_CO = 'Requerido, recibido, consumido, disponibilidad de los componentes proporcionados por el cliente.';tr = 'Müşterinin sağladığı gerekli, alınan, tüketilen ve kullanılabilir malzemeler.';it = 'Richieste, ricevute, utilizzate, disponibilità di componenti fornite dal cliente.';de = 'Erforderlich, erhalten, verbraucht, Verfügbarkeit von kundenseitigen Komponenten.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SubcontractorOrderReceivedStatement, "Default");
	OptionSettings.Details = NStr("en = 'Planned, produced, issued and invoiced finished products that released under subcontracting agreements.'; ru = 'Запланированное, изготовленное, выданное количество готовой продукции и количество готовой продукции по инвойсу, выданное по договорам на переработку.';pl = 'Zaplanowane, wyprodukowane, wydane i zafakturowane produkty gotowe, wydane w ramach umów o podwykonawstwo.';es_ES = 'Planificados, producidos, emitidos y facturados productos terminados que se lanzaron bajo acuerdos de subcontratación.';es_CO = 'Planificados, producidos, emitidos y facturados productos terminados que se lanzaron bajo acuerdos de subcontratación.';tr = 'Alt yüklenici anlaşmaları kapsamında planlanan, üretilen, düzenlenen ve faturalandırılan nihai ürünler.';it = 'Articoli finiti pianificati, prodotti, emessi e fatturati, rilasciati in base ad accordi di subfornitura.';de = 'Geplante, produzierte, ausgegebene und in Rechnung gestellte Fertigprodukte freigegeben unter Verträgen für Subunternehmerbestellung.'");
	// end Drive.FullVersion 
	
	// End Subcontracting
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SummaryOfGeneratedDocuments, "Supplier");
	OptionSettings.Enabled = False;
	OptionSettings.Details = NStr("en = 'Generated documents summary for suppliers'; ru = 'Сводка созданных документов для поставщиков';pl = 'Podsumowanie wygenerowanych dokumentów dla dostawców';es_ES = 'Resumen de los documentos generados para proveedores';es_CO = 'Resumen de los documentos generados para proveedores';tr = 'Tedarikçiler için oluşturulan belgeler özeti';it = 'Riassunti dei documenti generati per i fornitori';de = 'Zusammenfassung generierte Dokumente für Lieferanten'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.SummaryOfGeneratedDocuments, "Customer");
	OptionSettings.Enabled = False;
	OptionSettings.Details = NStr("en = 'Generated documents summary for customers'; ru = 'Сводка созданных документов для покупателей';pl = 'Podsumowanie wygenerowanych dokumentów dla nabywców';es_ES = 'Resumen de los documentos generados para clientes';es_CO = 'Resumen de los documentos generados para clientes';tr = 'Müşteriler için oluşturulan belgeler özeti';it = 'Riassunti dei documenti generati per i clienti';de = 'Zusammenfassung generierte Dokumente für Kunden'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ClosingInvoices, "Default");
	OptionSettings.Details = NStr("en = 'The report shows the variance between the quantities of services invoiced and provided
		|as well as the amount of services to invoice.'; 
		|ru = 'Отчет показывает отклонение между количеством услуг, за которые выставлен инвойс, и количеством предоставленных услуг
		|, а также количеством услуг, за которые следует выставить инвойс.';
		|pl = 'Raport pokazuje odchylenie między zafakturowanymi ilościami i usługami i dostarczonymi
		|a także wartość usług do zafakturowania.';
		|es_ES = 'El informe muestra la variación entre las cantidades de servicios facturados y prestados,
		|así como el importe de los servicios a facturar.';
		|es_CO = 'El informe muestra la variación entre las cantidades de servicios facturados y prestados,
		|así como el importe de los servicios a facturar.';
		|tr = 'Rapor, faturalandırılan ve sağlanan hizmetlerin miktarları arasındaki farkın yanı sıra
		|faturalandırılacak hizmet tutarını da gösterir.';
		|it = 'Il report mostra la variazione tra le quantità di servizi fatturati e fornisce 
		|l''importo dei servizi da fatturare.';
		|de = 'Der Bericht zeigt die Abweichung zwischen den Mengen von in Rechnung gestellten und 
		|verbrachten Dienstleistungen als die Menge von in Rechnung zustellenden Dienstleistungen.'");
	OptionSettings.FunctionalOptions.Add("IssueClosingInvoices");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.KitOrderStatement, "Statement");
	OptionSettings.Details = NStr("en = 'Opening balance, ordered product quantity, assembled or disassembled product quantity, and closing balance.'; ru = 'Начальный остаток, количество заказанной номенклатуры, количество собранной или разобранной номенклатуры и конечный остаток.';pl = 'Saldo początkowe, ilość zamówionego produktu, ilość zebranych i rozebranych produktów, i saldo końcowe.';es_ES = 'Saldo inicial, cantidad de productos pedidos, cantidad de productos ensamblados o desmontados y saldo final.';es_CO = 'Saldo inicial, cantidad de productos pedidos, cantidad de productos ensamblados o desmontados y saldo final.';tr = 'Açılış bakiyesi, sipariş edilen ürün miktarı, monte veya demonte edilen ürün miktarı ve kapanış bakiyesi.';it = 'Saldo iniziale, quantità articolo ordinata, quantità articolo assemblato o smontato, e bilancio di chiusura.';de = 'Anfangssaldo, bestellte Produktmenge, montierte oder demontierte Produktmenge und Abschlusssaldo.'");
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.KitOrderStatement, "Balance");
	OptionSettings.Details = NStr("en = 'The report shows the order statuses within the specified period.'; ru = 'В отчете отображаются статусы заказов за указанный период.';pl = 'Raport pokazuje statusy zamówienia w określonym określonym.';es_ES = 'El informe muestra los estados del pedido dentro del período especificado.';es_CO = 'El informe muestra los estados del pedido dentro del período especificado.';tr = 'Rapor, belirtilen dönem içindeki sipariş/emir durumlarını gösteriyor.';it = 'Il report mostra gli stati dell''ordine entro il periodo specificato.';de = 'Der Bericht zeigt die Auftragsstatus innerhalb des angegebenen Zeitraums an.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProfitAndLossAccountRecorders, "Default");
	OptionSettings.Details = NStr("en = 'The report shows the documents that posted entries to the selected GL account.'; ru = 'В отчете показаны документы, которые сделали проводки по выбранным счетам учета.';pl = 'Raport pokazuje dokumenty, który zatwierdziły wpisy na wybranym koncie księgowym.';es_ES = 'El informe muestra los documentos que enviaron entradas a la cuenta del libro mayor seleccionada.';es_CO = 'El informe muestra los documentos que enviaron entradas a la cuenta del libro mayor seleccionada.';tr = 'Rapor, seçilen muhasebe hesabına giriş kaydeden belgeleri gösterir.';it = 'Il report mostra i documenti che hanno pubblicato inserimenti nel conto mastro selezionato.';de = 'Der Bericht zeigt die Dokumente mit welchen die gebuchten Einträge zu den ausgewählten Hauptbuch-Konten gebucht sind an.'");
	OptionSettings.VisibleByDefault = False;
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProjectPhases, "StuckPhases");
	OptionSettings.Details = NStr("en = 'Project phases past their deadline and still pending completion.'; ru = 'Этапы проекта просрочены и все еще ожидают завершения.';pl = 'Termin etapów projektów już minął i one wciąż oczekują na wykonanie.';es_ES = 'Fases del proyecto vencidas y aún pendientes de finalizar.';es_CO = 'Fases del proyecto vencidas y aún pendientes de finalizar.';tr = 'Proje evrelerinin bitiş tarihleri geçti ve hala tamamlanmaları bekleniyor.';it = 'Fasi oltre la scadenza ancora in attesa del completamento.';de = 'Projektphasen nach Fälligkeitstermin und mit anstehendem Abschluss.'");
	OptionSettings.Placement.Clear();
	OptionSettings.Placement.Insert(Metadata.Subsystems.Enterprise.Subsystems.ProjectManagement);
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProjectPhases, "LateStart");
	OptionSettings.Details = NStr("en = 'Project phases that started later than the planned start date, but not yet overdue.'; ru = 'Этапы проекта, которые начались позже запланированной даты начала, но еще не просрочены.';pl = 'Etapy projektów, które rozpoczęły się później niż zaplanowana data rozpoczęcia, ale jeszcze nie są zaległe.';es_ES = 'Fases del proyecto que se iniciaron más tarde de la fecha de inicio prevista, pero que aún no están atrasadas.';es_CO = 'Fases del proyecto que se iniciaron más tarde de la fecha de inicio prevista, pero que aún no están atrasadas.';tr = 'Planlanan başlangıç tarihinden geç başlamış, ancak henüz vadesi geçmemiş proje evreleri.';it = 'Fasi del progetto avviate dopo la data di avvio programmata, ma non ancora in ritardo.';de = 'Projektphasen die nach dem geplanten Startdatum gestartet aber noch nicht überfällig sind.'");
	OptionSettings.Placement.Clear();
	OptionSettings.Placement.Insert(Metadata.Subsystems.Enterprise.Subsystems.ProjectManagement);
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProjectPhasesStatusChanges, "ShouldBeStarted");
	OptionSettings.Details = NStr("en = 'Project phases with planned start date coming soon.'; ru = 'Этапы проекта с приближающейся запланированной датой начала.';pl = 'Etapy projektu z nadchodzącą zaplanowaną datą rozpoczęcia.';es_ES = 'Fases del proyecto con fecha de inicio prevista próximamente.';es_CO = 'Fases del proyecto con fecha de inicio prevista próximamente.';tr = 'Planlanan başlangıç tarihi yaklaşan proje evreleri.';it = 'Fasi del progetto con la data di avvio programmata a breve.';de = 'Projektphasen mit einem bald anfallenden geplanten Startdatum.'");
	OptionSettings.Placement.Clear();
	OptionSettings.Placement.Insert(Metadata.Subsystems.Enterprise.Subsystems.ProjectManagement);
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProjectPhasesStatusChanges, "ShouldBeCompleted");
	OptionSettings.Details = NStr("en = 'Project phases with planned end date coming soon.'; ru = 'Этапы проекта с приближающейся запланированной датой завершения.';pl = 'Etapy projektu z nadchodzącą zaplanowaną datą zakończenia.';es_ES = 'Fases del proyecto con fecha final prevista próximamente.';es_CO = 'Fases del proyecto con fecha final prevista próximamente.';tr = 'Planlanan bitiş tarihi yaklaşan proje evreleri.';it = 'Fasi del progetto con la data di fine programmata a breve.';de = 'Projektphasen mit einem bald anfallenden geplanten Enddatum.'");
	OptionSettings.Placement.Clear();
	OptionSettings.Placement.Insert(Metadata.Subsystems.Enterprise.Subsystems.ProjectManagement);
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ProjectPhasesProgress, "Default");
	OptionSettings.Details = NStr("en = 'Percent of project phases completion.'; ru = 'Процент завершения этапов проекта.';pl = 'Procent zakończenia etapów projektu.';es_ES = 'Porcentaje de finalización de las fases del proyecto.';es_CO = 'Porcentaje de finalización de las fases del proyecto.';tr = 'Proje evrelerinin tamamlanma yüzdesi.';it = 'Percentuale di completamento delle fasi del progetto.';de = 'Prozentualer Anteil des Abschlusses von Projektphasen.'");
	OptionSettings.Placement.Clear();
	OptionSettings.Placement.Insert(Metadata.Subsystems.Enterprise.Subsystems.ProjectManagement);
	
	// begin Drive.FullVersion
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.ManufacturingOverheadsStatement, "Default");
	OptionSettings.Details = NStr("en = 'Opening balance, Actual overheads, Allocated by overhead rates, Allocated by adjusted allocation rate, Written off to COGS, Closing balance.'; ru = 'Начальный остаток, фактические накладные расходы, распределено по ставкам накладных расходов, распределено по скорректированной норме распределения, списано на себестоимость, конечный остаток.';pl = 'Saldo początkowe, Faktyczne koszty ogólne, Przydzielone według stawek kosztów ogólnych, Przydzielone według skorygowanej stawki skorygowanej stawki alokacji, Rozchodowano do KWS, Saldo końcowe.';es_ES = 'Saldo de apertura, Recargos actuales, Asignado por las tasas del recargo, Asignado por la tasa de asignación ajustada, Amortizado por COGS, Saldo final.';es_CO = 'Saldo de apertura, Recargos actuales, Asignado por las tasas del recargo, Asignado por la tasa de asignación ajustada, Amortizado por COGS, Saldo final.';tr = 'Açılış bakiyesi, Gerçek genel giderler, Genel gider oranları tarafından tahsis edilen, Düzeltilmiş tahsis oranı tarafından tahsis edilen, SMM''ye yazılan, Kapanış bakiyesi.';it = 'Saldo iniziale, Spese generali effettive, Allocate per tasso di spesa generale, Allocate per tasso di spesa generale rettificato, Cancellazione costo articoli venduti, Saldo di chiusura.';de = 'Anfangssaldo, aktuelle Fertigungsgemeinkosten, Zugeordnet nach Sätzen von Fertigungsgemeinkosten, Zugeordnet nach angepasstem Zuordnungssatz, Abgeschrieben in Wareneinsatz, Abschlusssaldo.'");
	// end Drive.FullVersion
	
	OptionSettings = ReportsOptions.OptionDetails(Settings, Metadata.Reports.TrialBalanceMaster, "TBM");
	OptionSettings.Details = NStr("en = 'The opening balance, turnover, and closing balance of all accounts.'; ru = 'Начальный остаток, оборот и конечный остаток всех счетов.';pl = 'Saldo początkowe, obrót oraz saldo końcowe wszystkich kont.';es_ES = 'El saldo inicial, la facturación y el saldo final de todas las cuentas.';es_CO = 'El saldo inicial, la facturación y el saldo final de todas las cuentas.';tr = 'Tüm hesapların açılış bakiyesi, cirosu ve kapanış bakiyesi.';it = 'Saldo iniziale, fatturato e saldo di chiusura di tutti i conti.';de = 'Der Anfangssaldo, Umsatz, und Abschlusssaldo aller Konten'");
	OptionSettings.Placement.Clear();
	OptionSettings.Placement.Insert(Metadata.Subsystems.Accounting);
	
	HighlightKeyReports(Settings);
	HighlightSecondaryReports(Settings);
	
EndProcedure

#EndRegion

#Region Private

Procedure MakeMain(Settings,ReportName, OptionsAsString)

	OptionsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(OptionsAsString);
	
	For Each VariantName In OptionsArray Do
	
		Try
			Variant = ReportsOptions.OptionDetails(Settings, Metadata.Reports[ReportName], VariantName);
		Except
			Continue;
		EndTry;
		
		For Each PlacementInSubsystem In Variant.Placement Do
			Variant.Placement.Insert(PlacementInSubsystem.Key,"Important");
		EndDo;
	
	EndDo;

EndProcedure

// Moves the specified options of specified report into SeeAlso
//
// Parameters
//   Settings (ValueTree) Used to describe settings of reports
//   and variants see description to ReportsVariants.ReportVariantsConfigurationSettingsTree()
//
//  ReportName  - String - Report name that shall be transferred to SeeAlso
//
//  Variants  - String - Report options, separated
//                 by comma, that shall be transferred into SeeAlso
//
Procedure MakeSecondary(Settings,ReportName, OptionsAsString)

	OptionsArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(OptionsAsString);
	
	For Each VariantName In OptionsArray Do
	
		Try
			Variant = ReportsOptions.OptionDetails(Settings, Metadata.Reports[ReportName], VariantName);
		Except
			Continue;
		EndTry;
		
		For Each PlacementInSubsystem In Variant.Placement Do
			Variant.Placement.Insert(PlacementInSubsystem.Key,"SeeAlso");
		EndDo;
	
	EndDo;

EndProcedure

Procedure HighlightKeyReports(Settings)

	MakeMain(Settings,"AvailableStock","Default");
	MakeMain(Settings,"StatementOfAccount","Statement in currency (briefly)");
	MakeMain(Settings,"SalesOrdersTrend","Default");
	MakeMain(Settings,"PurchaseOrdersOverview","Default");
	MakeMain(Settings,"SupplyPlanning","Default");
	MakeMain(Settings,"StockSummary","Statement");
	MakeMain(Settings,"CashBalance","Balance");
	MakeMain(Settings,"CashBalance","Statement");
	MakeMain(Settings,"PaymentCalendar","Default");
	MakeMain(Settings,"EarningsAndDeductions","InCurrency");
	MakeMain(Settings,"PayStatements","StatementInCurrency");
	MakeMain(Settings,"NetSales","GrossProfit");
	MakeMain(Settings,"NetSales","SalesDynamics");
	MakeMain(Settings,"IncomeAndExpenses","Statement");
	MakeMain(Settings,"IncomeAndExpensesByCashMethod","Default");
	MakeMain(Settings,"TrialBalance","TBS");
	MakeMain(Settings,"SalesWithCardBasedDiscounts","SalesWithCardBasedDiscounts");
	MakeMain(Settings,"AutomaticDiscountSales","AutomaticDiscounts");
	MakeMain(Settings, "SupplierStatement", "StatementInCurrency");
	MakeMain(Settings, "CustomerStatement", "StatementInCurrency");
	MakeMain(Settings, "SubcontractorOrderIssuedStatement", "FinishedProducts");
	MakeMain(Settings, "SubcontractorOrderIssuedStatement", "Components");
	
	// begin Drive.FullVersion
	MakeMain(Settings,"ProductRelease","Default");
	// end Drive.FullVersion

EndProcedure

Procedure HighlightSecondaryReports(Settings)

	MakeSecondary(Settings,"StatementOfAccount","Statement,Balance,Statement in currency,Balance in currency");
	MakeSecondary(Settings,"AccountsReceivableAging","Default");
	MakeSecondary(Settings,"CashRegisterStatement","Statement,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"POSSummary","Statement,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"StockStatement","Statement,Balance");
	MakeSecondary(Settings,"Backorders","Statement");
	MakeSecondary(Settings,"CashBalance","Statement,Balance,Movements analysis");
	MakeSecondary(Settings,"CashFlowVarianceAnalysis","Default,Planfact analysis");
	MakeSecondary(Settings,"EarningsAndDeductions","Default");
	MakeSecondary(Settings,"PayStatements","Statement,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"CashBudget","Planfact analysis");
	MakeSecondary(Settings,"ProfitAndLossBudget","Planfact analysis");
	MakeSecondary(Settings,"CostOfGoodsManufactured","Full");
	MakeSecondary(Settings,"Purchases","Default");
	MakeSecondary(Settings,"StockSummary","Balance");
	MakeSecondary(Settings,"SurplusesAndShortages","Default");
	MakeSecondary(Settings,"StockReceivedFromThirdParties","Statement,Balance");
	MakeSecondary(Settings,"StockTransferredToThirdParties","Statement,Balance");
	// begin Drive.FullVersion
	MakeSecondary(Settings,"ProductionOrderStatement","Balance");
	// end Drive.FullVersion
	MakeSecondary(Settings,"AdvanceHolders","Statement,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"AccountsReceivable","Statement,StatementInCurrency,Balance,BalanceInCurrency");
	MakeSecondary(Settings,"SalesOrdersStatement","Statement,Balance");
	MakeSecondary(Settings,"PurchaseOrdersStatement","Statement,Balance");
	MakeSecondary(Settings,"Backorders","Statement,Balance");
	MakeSecondary(Settings,"AccountsPayable","Statement,Balance,StatementInCurrency,BalanceInCurrency");
	MakeSecondary(Settings,"AccountsPayableAging","Default");
	MakeSecondary(Settings,"StatementOfTaxAccount","Balance");
	MakeSecondary(Settings,"StatementOfCost","Balance");
	MakeSecondary(Settings,"StockStatementWithCostLayers","Statement,Balance");
	MakeSecondary(Settings,"KitOrderStatement","Balance");
	
EndProcedure

#EndRegion
