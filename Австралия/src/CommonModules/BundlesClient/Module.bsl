
#Region Public

Function ProcessNotifications(Form, EventName, Source) Export
	
	Return (EventName = EventNameOfChangingBundleComponents() And Source = Form.UUID);
	
EndFunction

Procedure DeleteBundleRows(BundleProduct, BundleCharacteristic, Inventory, AddedBundles, Variant = Undefined) Export
	
	FilterStructure = New Structure;
	FilterStructure.Insert("BundleProduct", BundleProduct);
	FilterStructure.Insert("BundleCharacteristic", BundleCharacteristic);
	If Variant <> Undefined Then
		FilterStructure.Insert("Variant", Variant);
	EndIf;
	BundleRows = Inventory.FindRows(FilterStructure);
	For Each Row In BundleRows Do
		Inventory.Delete(Row);
	EndDo;
	AddedRows = AddedBundles.FindRows(FilterStructure);
	For Each Row In AddedRows Do
		AddedBundles.Delete(Row);
	EndDo;
	
EndProcedure

Procedure DeleteSubordinateTableRows(MainTable, SubordinateTable, ConnectionKeyName = "ConnectionKey") Export
	
	ConnectionKeyArray = New Array;
	
	For Each Row In MainTable Do
		If Row[ConnectionKeyName] > 0 And ConnectionKeyArray.Find(Row[ConnectionKeyName]) = Undefined Then
			ConnectionKeyArray.Add(Row[ConnectionKeyName]);
		EndIf;
	EndDo;
	
	RowsToDelete = New Array;
	For Each Row In SubordinateTable Do
		If ConnectionKeyArray.Find(Row[ConnectionKeyName]) = Undefined Then
			RowsToDelete.Add(Row);
		EndIf;
	EndDo;
	
	For Each Row In RowsToDelete Do
		SubordinateTable.Delete(Row);
	EndDo;
	
EndProcedure

Function QuestionTextSeveralBundles() Export
	
	Return NStr("en = 'The current line is a part of the bundle. What would you like to do?'; ru = 'Выделенная строка входит в набор. Какие действия следует предпринять?';pl = 'Bieżący wiersz jest częścią zestawu. Co chcesz zrobić?';es_ES = 'La línea actual es parte del paquete. ¿Qué le gustaría hacer?';es_CO = 'La línea actual es parte del paquete. ¿Qué le gustaría hacer?';tr = 'Mevcut satır ürün setinin parçasıdır. Ne yapmak istersiniz?';it = 'La linea corrente è parte di un kit di prodotti. Cosa desidera fare?';de = 'Die aktuelle Zeile ist ein Teil der Artikelgruppe. Was möchten Sie tun?'");
	
EndFunction

Function QuestionTextOneBundle() Export
	
	Return NStr("en = 'The current line is a part of the bundle. You can only delete the whole bundle'; ru = 'Выделенная строка входит в набор. Возможно удаление только всего комплекта';pl = 'Bieżący wiersz jest częścią zestawu. Możesz usunąć tylko cały zestaw';es_ES = 'La línea actual es parte del paquete. Usted sólo puede borrar todo el paquete';es_CO = 'La línea actual es parte del paquete. Usted sólo puede borrar todo el paquete';tr = 'Mevcut satır ürün setinin parçasıdır. Sadece tüm set silinebilir';it = 'La linea corrente è parte di un kit di prodotti. Si può eliminare solo l''intero kit di prodotti';de = 'Die aktuelle Zeile ist ein Teil der Artikelgruppe. Sie können nur die gesamte Artikelgruppe löschen.'");
	
EndFunction

Function AnswerDeleteAllBundles() Export
	
	Return NStr("en = 'Delete the whole bundle'; ru = 'Удалить весь набор';pl = 'Usuń cały zestaw';es_ES = 'Borrar todo el paquete';es_CO = 'Borrar todo el paquete';tr = 'Tüm ürün setini sil';it = 'Elimina l''intero kit di prodotti';de = 'Die gesamte Artikelgruppe löschen'");
	
EndFunction

Function AnswerReduceQuantity() Export
	
	Return NStr("en = 'Reduce bundle quantity by 1'; ru = 'Уменьшить количество наборов на 1';pl = 'Zmniejsz ilość zestawu o 1';es_ES = 'Reducir la cantidad de paquetes en 1';es_CO = 'Reducir la cantidad de paquetes en 1';tr = 'Ürün seti miktarını 1 azalt';it = 'Ridurre quantità del kit di prodotti di 1';de = 'Menge der Artikelgruppe um 1 reduzieren'");
	
EndFunction

Function AswerDeleteAllComponents() Export
	
	Return NStr("en = 'Delete all bundle components'; ru = 'Удалить все компоненты набора';pl = 'Usuń wszystkie komponenty zestawu';es_ES = 'Borrar todos los componentes del paquete';es_CO = 'Borrar todos los componentes del paquete';tr = 'Tüm set malzemelerini sil';it = 'Elimina tutti i componenti del kit di prodotti';de = 'Gesamtmaterialbestand der Artikelgruppe löschen'");
	
EndFunction

Function AswerChangeComponents() Export
	
	Return NStr("en = 'Change components of the bundle'; ru = 'Изменить компоненты набора';pl = 'Zmień komponenty zestawu';es_ES = 'Cambiar los componentes del paquete';es_CO = 'Cambiar los componentes del paquete';tr = 'Ürün seti malzemelerini değiştir';it = 'Modifica i componenti del kit di prodotti';de = 'Materialbestand der Artikelgruppe ändern'");
	
EndFunction

#EndRegion

#Region Internal

Function EventNameOfChangingBundleComponents() Export
	
	Return "BundleComponentsChanged";
	
EndFunction

#EndRegion