#Region Public

Procedure ReadAdditionalInformationPanelData(Form, Counterparty) Export 
	
	Items = Form.Items;
	
	ViewStatemenOfAccount = AccessRight("View", Metadata.Reports.StatementOfAccount);
	ViewNetSales = AccessRight("View", Metadata.Reports.NetSales);

	Items.AdditionalInformationPanel.Visible = ValueIsFilled(Counterparty);
	
	If Not ValueIsFilled(Counterparty) Then
		Return;
	EndIf;
	
	LargeFont = StyleFonts.InformationPanelLargeFont;
	SmallFont  = StyleFonts.InformationPanelSmallFont;
	
	Company = Undefined;
	
	Query = New Query;
	Query.SetParameter("Counterparty", Counterparty);
	
	If ViewStatemenOfAccount Then
		
		Query.Text = 
		"SELECT ALLOWED
		|	AccountsPayableBalance.PresentationCurrency AS PresentationCurrency,
		|	-AccountsPayableBalance.AmountBalance AS AmountBalance
		|INTO TT_PRM
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			,
		|			Counterparty = &Counterparty
		|				AND &CompanyFilter) AS AccountsPayableBalance
		|
		|UNION ALL
		|
		|SELECT
		|	AccountsReceivableBalance.PresentationCurrency,
		|	AccountsReceivableBalance.AmountBalance
		|FROM
		|	AccumulationRegister.AccountsReceivable.Balance(
		|			,
		|			Counterparty = &Counterparty
		|				AND &CompanyFilter) AS AccountsReceivableBalance
		|
		|UNION ALL
		|
		|SELECT
		|	MiscellaneousPayableBalance.PresentationCurrency,
		|	MiscellaneousPayableBalance.AmountBalance
		|FROM
		|	AccumulationRegister.MiscellaneousPayable.Balance(
		|			,
		|			Counterparty = &Counterparty
		|				AND &CompanyFilter) AS MiscellaneousPayableBalance
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SUM(TT_PRM.AmountBalance) AS Amount,
		|	TT_PRM.PresentationCurrency AS PresentationCurrency
		|FROM
		|	TT_PRM AS TT_PRM
		|
		|GROUP BY
		|	TT_PRM.PresentationCurrency";
		
		
		If Form.Object.Property("Company", Company) Then 
			
			Query.Text = StrReplace(Query.Text, "&CompanyFilter", "Company = &Company");
			Query.SetParameter("Company", Company);
			
		Else 
			
			Query.SetParameter("CompanyFilter", True);
			
		EndIf;
		
		Sel = Query.Execute().Select();
		
		EmptyAmount = (Sel.Count() = 0);
		
		FSParts = New Array;
		
		While Sel.Next() Or EmptyAmount Do 
			
			If EmptyAmount Then
				Amount = 0;
			Else
				Amount = Sel.Amount;
			EndIf;			
			
			If Amount < 0 Then
				FSParts.Add(New FormattedString(NStr("en = 'Amount owed'; ru = 'Сумма задолженности';pl = 'Kwota należna';es_ES = 'Cantidad adeudada';es_CO = 'Cantidad adeudada';tr = 'Alacak';it = 'Importo dovuto';de = 'Geschuldeter Betrag'") + " ", LargeFont));
				Amount = -Amount;
			Else
				FSParts.Add(New FormattedString(NStr("en = 'Amount due'; ru = 'Сумма долга';pl = 'Kwota należna';es_ES = 'Cantidad debida';es_CO = 'Cantidad debida';tr = 'Borç';it = 'Importo dovuto';de = 'Fälliger Betrag'") + " ", LargeFont));
			EndIf;
			
			AmountInWords = Format(Amount, "NFD=2; NDS=,; NGS=' '; NZ=0,00");
			CommaPosition = StrFind(AmountInWords, ",");
			
			NumberParts = New Array;
			NumberParts.Add(New FormattedString(Left(AmountInWords, CommaPosition), LargeFont));
			NumberParts.Add(New FormattedString(Mid(AmountInWords, CommaPosition + 1), SmallFont));
			
			FSParts.Add(New FormattedString(NumberParts, , , , "DebtBalance"));
			
			FSParts.Add(" " + ?(EmptyAmount, "", Sel.PresentationCurrency) + Chars.LF);
			
			EmptyAmount = False;
		EndDo;
			
		Items.DebtBalance.Title = New FormattedString(FSParts, , StyleColors.MinorInscriptionText);
		
	EndIf;
	
	If ViewNetSales Then
		
		Query.Text =
		"SELECT ALLOWED
		|	SalesTurnovers.PresentationCurrency AS PresentationCurrency,
		|	SUM(SalesTurnovers.AmountTurnover) AS Amount
		|FROM
		|	AccumulationRegister.Sales.Turnovers(
		|			,
		|			,
		|			,
		|			Document REFS Document.SalesInvoice
		|				AND Counterparty = &Counterparty
		|				AND &CompanyFilter) AS SalesTurnovers
		|
		|GROUP BY
		|	SalesTurnovers.PresentationCurrency
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	SalesInvoice.Ref AS Document,
		|	SalesInvoice.Date AS Date
		|FROM
		|	Document.SalesInvoice AS SalesInvoice
		|WHERE
		|	SalesInvoice.Posted
		|	AND SalesInvoice.Counterparty = &Counterparty
		|
		|ORDER BY
		|	SalesInvoice.PointInTime DESC";
		
		If Form.Object.Property("Company", Company) Then 
			
			Query.Text = StrReplace(Query.Text, "&CompanyFilter", "Company = &Company");
			Query.SetParameter("Company", Company);
			
		Else 
			
			Query.SetParameter("CompanyFilter", True);
			
		EndIf;
		
		QueryResults = Query.ExecuteBatch();
		
		Sel = QueryResults[0].Select();
		
		EmptySales = (Sel.Count() = 0);
		
		FSParts = New Array;
		FSParts.Add(New FormattedString(NStr("en = 'Sales'; ru = 'Продажи';pl = 'Sprzedaż';es_ES = 'Ventas';es_CO = 'Ventas';tr = 'Satış';it = 'Vendite';de = 'Verkäufe'") + " ", LargeFont));
		
		While Sel.Next() Or EmptySales Do 
			
			If EmptySales Then
				Amount = 0;
			Else
				Amount = Sel.Amount;
			EndIf;
			                                                		
			AmountInWords = Format(Amount, "NFD=2; NDS=,; NGS=' '; NZ=0,00");
			CommaPosition = StrFind(AmountInWords, ",");
			
			NumberParts = New Array;
			NumberParts.Add(New FormattedString(Left(AmountInWords, CommaPosition), LargeFont));
			NumberParts.Add(New FormattedString(Mid(AmountInWords, CommaPosition + 1), SmallFont));
			
			FSParts.Add(New FormattedString(NumberParts, , , , "Sales"));
			FSParts.Add(" " + ?(EmptySales, "", Sel.PresentationCurrency) + Chars.LF);
			
			EmptySales = False;
		EndDo;
		
		Items.SalesAmount.Title = New FormattedString(FSParts, , StyleColors.MinorInscriptionText);
		
		Sel = QueryResults[1].Select();
		If Sel.Next() Then
			Date = Sel.Date;
			Hyperlink = GetURL(Sel.Document);
		Else
			Date = '00010101';
			Hyperlink = "";
		EndIf;
		
		FSParts = New Array;
		FSParts.Add(NStr("en = 'Last sale'; ru = 'Последняя продажа';pl = 'Ostatnia sprzedaż';es_ES = 'Última venta';es_CO = 'Última venta';tr = 'Son satış';it = 'Ultima vendita';de = 'Letzter Verkauf'") + " ");
		FSParts.Add(New FormattedString(Format(Date, "L=en; DLF=D; DE=<none>"), , , , Hyperlink));
		
		Items.LastSale.Title = New FormattedString(FSParts, LargeFont, StyleColors.MinorInscriptionText);
		
	EndIf;
	
	If GetFunctionalOption("UseDocumentEvent") Then
		
		Query.Text =
		"SELECT ALLOWED DISTINCT
		|	EventParticipants.Ref AS Ref
		|INTO TT_Events
		|FROM
		|	Document.Event.Participants AS EventParticipants
		|WHERE
		|	EventParticipants.Contact = &Counterparty
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED TOP 1
		|	Events.Ref AS Event,
		|	Events.EventBegin AS Date
		|FROM
		|	TT_Events AS TT_Events
		|		INNER JOIN Document.Event AS Events
		|		ON TT_Events.Ref = Events.Ref
		|WHERE
		|	NOT Events.DeletionMark
		|
		|ORDER BY
		|	Events.EventBegin DESC";
		
		Sel = Query.Execute().Select();
		If Sel.Next() Then
			Date = Sel.Date;
			Hyperlink = GetURL(Sel.Event);
		Else
			Date = '00010101';
			Hyperlink = "";
		EndIf;
		
		FSParts = New Array;
		FSParts.Add(NStr("en = 'Last event'; ru = 'Последнее событие';pl = 'Ostatnie wydarzenie';es_ES = 'Último evento';es_CO = 'Último evento';tr = 'Son etkinlik';it = 'Ultimo evento';de = 'Letztes Ereignis'") + " ");
		FSParts.Add(New FormattedString(Format(Date, "L=en; DLF=D; DE=<none>"), , , , Hyperlink));
		
		Items.LastEvent.Title = New FormattedString(FSParts, LargeFont, StyleColors.MinorInscriptionText);
		
	EndIf;
	
EndProcedure

#EndRegion
