#Region ProcedureFormEventHandlers

&AtServer
//  Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not Parameters.Property("Order") Then
		
		Message = New UserMessage();
		Message.Text = NStr("en = 'The report can be generated only from Purchase order.'; ru = 'Отчет может быть создан только на основании заказа поставщику.';pl = 'Raport można wygenerować tylko ze Zamówienia zakupu.';es_ES = 'El informe sólo se puede generar desde la Orden de compra.';es_CO = 'El informe sólo se puede generar desde la Orden de compra.';tr = 'Rapor sadece Satın alma siparişinden oluşturulabilir.';it = 'Il report può essere generato solamente da un Ordine di acquisto.';de = 'Der Bericht kann nur aus Bestellung and Lieferant generiert werden.'");
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

#EndRegion
