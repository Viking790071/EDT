
#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			If Not Parameters.Filter.Owner.UseBatches Then
				
				If Not UsersClientServer.IsExternalUserSession() Then
					MessageText = NStr("en = 'Batch tracking is disabled. To turn it on:
					|1. Go to Settings > Purchases/Warehouse.
					|2. Under ""Inventory (Products)"", select ""Inventory accounting by batches"".'; 
					|ru = 'Учет по партиям отключен. Чтобы включить его:
					|1. Перейдите в меню Настройки > Закупки/Склад.
					|2. В разделе ""Запасы (номенклатура)"" установите флажок ""Учет запасов в разрезе партий"".';
					|pl = 'Śledzenie partii jest wyłączone. W celu włączenia:
					|1. Przejdź do Ustawienia > Zakup/Magazyn.
					|2. W ""Zapasy (Produkty)"", zaznacz ""Ewidencja zapasów według partii"".';
					|es_ES = 'El rastreo del lote está desactivado. Para activarlo:
					|1. Ir a Configuraciones > Compras / Almacenes.
					|2. En ""Inventario (productos)"", seleccione ""Contabilidad de inventario por lotes"".';
					|es_CO = 'El rastreo del lote está desactivado. Para activarlo:
					|1. Ir a Configuraciones > Compras / Almacenes.
					|2. En ""Inventario (productos)"", seleccione ""Contabilidad de inventario por lotes"".';
					|tr = 'Parti takibi kapalı. Açmak için:
					|1. Ayarlar Ayarlar > Satın alma / Ambar sayfasına gidin.
					|2. ""Stok (Ürünler)"" bölümünde ""Partilere göre envanter muhasebesi""ni seçin.';
					|it = 'Tracciamento del lotto disattivato. Per attivarlo:
					|1. Andare in impostazioni > Acquisti/Magazzino. 
					|2. In ""Scorte (Articoli)"", selezionare ""Contabilizzazione delle scorte per lotti"".';
					|de = 'Chargenverfolgung ist deaktiviert. Um sie zu aktivieren:
					|1. Gehen Sie zu Einstellungen > Einkäufe / Lager.
					|2. Aktivieren Sie ""Bestandsbuchhaltung nach Chargen"" unter ""Bestand (Produkte)"".'");
					CommonClientServer.MessageToUser(MessageText,,,,Cancel);
				Else
					Cancel = True;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
