
#Region ProcedureFormEventHandlers

&AtServer
//  Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not Parameters.Property("Order") Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'The report can be generated only from Sales order.'; ru = 'Отчет может быть создан только на основании заказа покупателя.';pl = 'Raport można wygenerować tylko z Zamówienia sprzedaży.';es_ES = 'El informe sólo se puede generar desde la Orden de ventas.';es_CO = 'El informe sólo se puede generar desde la Orden de ventas.';tr = 'Rapor sadece Satış siparişinden oluşturulabilir.';it = 'Il report può essere generato soltanto da un Ordine cliente.';de = 'Der Bericht kann nur aus Kundenauftrag generiert werden.'");
		Message.Message();
		
		Cancel = True;
		Return;
		
	EndIf;
	
	DCSParameters = Report.SettingsComposer.Settings.DataParameters;
	DCSParameter = DCSParameters.Items.Find("Order");
	
	If DCSParameter <> Undefined Then
		DCSParameters.SetParameterValue("Order", Parameters.Order);
	EndIf;
	
	ComposeResult();
	
EndProcedure
// 

#EndRegion
