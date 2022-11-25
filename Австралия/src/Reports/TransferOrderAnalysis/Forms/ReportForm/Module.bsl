
#Region ProcedureFormEventHandlers

&AtServer
//  Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	If Not Parameters.Property("Order") Then
		
		Text = NStr("en = 'The report can be generated only from Transfer order.'; ru = 'Отчет может быть создан только на основании заказа на перемещение.';pl = 'Raport można wygenerować tylko z Zamówienia przeniesienia.';es_ES = 'El informe sólo se puede generar desde la Orden de transferencia.';es_CO = 'El informe sólo se puede generar desde la Orden de transferencia.';tr = 'Rapor sadece Transfer emrinden oluşturulabilir.';it = 'Il report può essere generato solo da un Ordine di trasferimento.';de = 'Der Bericht kann nur aus Transportauftrag generiert werden.'");
		CommonClientServer.MessageToUser(Text);
		
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
