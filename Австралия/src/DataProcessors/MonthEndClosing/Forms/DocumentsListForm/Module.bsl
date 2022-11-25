
#Region FormEvents

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("CurYear") Then
		
		SetFilterPeriod(Parameters.CurYear, Parameters.CurMonth);
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	SetParametersList();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "MonthEndClosingDataProcessorChangeCompany" Then
		
		FilterItems = List.Filter.Items;
		
		FieldCompany = New DataCompositionField("Company");
		
		For Each FilterItem In FilterItems Do
		
			If FilterItem.LeftValue = FieldCompany
				And Parameter.Property("Company") Then
				
				FilterItem.RightValue = Parameter.Company;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If EventName = "MonthEndClosingDataProcessorOnChangePeriod" Then
		
		ChangeFilterPeriod(Parameter.CurYear, Parameter.CurMonth);
		
	EndIf;
	
	If  EventName = "MonthEndClosingDataProcessorRefreshList" Then
		
		RefreshList();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableListItemsEventHandlers

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	ShowValue( , Items.List.CurrentData.Ref);
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetFilterPeriod(CurYear, CurMonth)
	
	FilterItems = List.Filter.Items;
	
	DateBegOfMonth = Date(CurYear+CurMonth+"01");
	DateEndOfMonth = EndOfMonth(DateBegOfMonth);
	
	NewFilter					= FilterItems.Add(Type("DataCompositionFilterItem"));
	NewFilter.Use				= True;
	NewFilter.LeftValue			= New DataCompositionField("Date");
	NewFilter.ComparisonType	= DataCompositionComparisonType.GreaterOrEqual;
	NewFilter.RightValue		= DateBegOfMonth;
	
	NewFilter					= FilterItems.Add(Type("DataCompositionFilterItem"));
	NewFilter.Use				= True;
	NewFilter.LeftValue			= New DataCompositionField("Date");
	NewFilter.ComparisonType	= DataCompositionComparisonType.LessOrEqual;
	NewFilter.RightValue		= DateEndOfMonth;
	
EndProcedure

&AtClient
Procedure ChangeFilterPeriod(CurYear, CurMonth)
	
	FilterItems = List.Filter.Items;
	
	DateBegOfMonth = Date(CurYear+CurMonth+"01");
	DateEndOfMonth = EndOfMonth(DateBegOfMonth);
	
	FieldDate = New DataCompositionField("Date");
	
	For Each FilterItem In FilterItems Do
		
		If FilterItem.LeftValue = FieldDate
			And FilterItem.ComparisonType	= DataCompositionComparisonType.GreaterOrEqual Then
			
			FilterItem.RightValue = DateBegOfMonth;
			
		EndIf;
		
		If FilterItem.LeftValue = FieldDate
			And FilterItem.ComparisonType	= DataCompositionComparisonType.LessOrEqual Then
			
			FilterItem.RightValue = DateEndOfMonth;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure SetParametersList()
	
	List.Parameters.SetParameterValue("StringDocumentMonthEndClosing", NStr("en = 'Month-end closing'; ru = 'Закрытие месяца';pl = 'Zamknięcie miesiąca';es_ES = 'Cierre del fin de mes';es_CO = 'Cierre del fin de mes';tr = 'Ay sonu kapanışı';it = 'Chiusura mensile';de = 'Monatsabschluss'"));
	List.Parameters.SetParameterValue("StringFixedAssetsDepreciation", NStr("en = 'Fixed asset depreciation'; ru = 'Амортизация основных средств';pl = 'Amortyzacja środków trwałych';es_ES = 'Depreciación del activo fijo';es_CO = 'Depreciación del activo fijo';tr = 'Sabit kıymet amortismanı';it = 'Ammortamento cespite';de = 'Abschreibungen auf das Anlagevermögen'"));
	
EndProcedure

&AtClient
Procedure RefreshList()
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion