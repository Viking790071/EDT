#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	// Serial numbers
	If WorkWithSerialNumbers.UseSerialNumbersBalance() = True Then
	
		For Each StringInventory In Inventory Do
			If StringInventory.Products.UseSerialNumbers Then
				FilterSerialNumbers = New Structure("ConnectionKey", StringInventory.ConnectionKey);
				FilterSerialNumbers = SerialNumbers.FindRows(FilterSerialNumbers);
				
				If TypeOf(StringInventory.MeasurementUnit)=Type("CatalogRef.UOM") Then
				    Ratio = StringInventory.MeasurementUnit.Ratio;
				Else
					Ratio = 1;
				EndIf;
				
				RowInventoryQuantity = StringInventory.Quantity * Ratio;
				
				If FilterSerialNumbers.Count() <> RowInventoryQuantity Then
					MessageText = NStr("en = 'The quantity of serial numbers differs from the quantity of units in line %Number%.'; ru = 'Число серийных номеров отличается от количества единиц в строке %Number%.';pl = 'Ilość numerów seryjnych różni się od ilości jednostek w wierszu %Number%.';es_ES = 'La cantidad de los números de serie es diferente de la cantidad de unidades en la línea %Number%.';es_CO = 'La cantidad de los números de serie es diferente de la cantidad de unidades en la línea %Number%.';tr = 'Seri numaralarının miktarı, %Number% satırındaki birimlerin miktarından farklı.';it = 'La quantità di numeri di serie differisce dalla quantità di unità in linea %Number%.';de = 'Die Menge der Seriennummern weicht von der Menge der Einheiten in Zeile %Number% ab.'");
					MessageText = MessageText + NStr("en = 'Serial numbers - %QuantityOfNumbers%, need %QuantityInRow%'; ru = ' Серийных номеров - %QuantityOfNumbers%, нужно %QuantityInRow%';pl = 'Numery seryjne - %QuantityOfNumbers%, potrzebne %QuantityInRow%';es_ES = 'Números de serie - %QuantityOfNumbers%, necesita %QuantityInRow%';es_CO = 'Números de serie - %QuantityOfNumbers%, necesita %QuantityInRow%';tr = 'Seri numaraları - %QuantityOfNumbers%, gereken %QuantityInRow%';it = 'I numeri di serie - %QuantityOfNumbers%, hanno bisogno di %QuantityInRow%';de = 'Seriennummern - %QuantityOfNumbers%, brauchen %QuantityInRow%'");
					MessageText = StrReplace(MessageText, "%Number%", StringInventory.LineNumber);
					MessageText = StrReplace(MessageText, "%QuantityOfNumbers%", FilterSerialNumbers.Count());
					MessageText = StrReplace(MessageText, "%QuantityInRow%", RowInventoryQuantity);
					
					Message = New UserMessage();
					Message.Text = MessageText;
					Message.Message();
					
				EndIf;
			EndIf; 
		EndDo;
	
	EndIf;
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;

EndProcedure

#EndRegion

#EndIf
