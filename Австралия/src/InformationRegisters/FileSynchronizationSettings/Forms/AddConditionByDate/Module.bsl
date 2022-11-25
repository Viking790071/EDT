#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("ArrayOfValues") Then // Return if there are no attributes with the date type.
		Return;
	EndIf;
	
	HasOnlyOneAttribute = Parameters.ArrayOfValues.Count() = 1;
	
	For Each Attribute In Parameters.ArrayOfValues Do
		Items.DateTypeAttribute.ChoiceList.Add(Attribute.Value, Attribute.Presentation);
		If HasOnlyOneAttribute Then
			DateTypeAttribute = Attribute.Value;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	If IntervalException = 0 Then
		CommonClientServer.MessageToUser(NStr("ru='Количество дней не может быть равно 0.'; en = 'Number of days cannot be equal to 0.'; pl = 'Ilość dni nie może wynosić 0.';es_ES = 'La cantidad de días no puede ser igual a 0.';es_CO = 'La cantidad de días no puede ser igual a 0.';tr = 'Gün sayısı 0 olamaz.';it = 'Il numero di giornate non può essere uguale a 0.';de = 'Die Anzahl der Tage darf nicht gleich 0 sein.'"),,, "IntervalException");
		Return;
	EndIf;
	
	If Not ValueIsFilled(DateTypeAttribute) Then
		CommonClientServer.MessageToUser(NStr("ru='Необходимо заполнить условия очистки файлов.'; en = 'Fill in file cleanup conditions.'; pl = 'Konieczne jest wypełnienie warunków czyszczenia plików.';es_ES = 'Es necesario rellenar las condiciones de vaciar los archivos.';es_CO = 'Es necesario rellenar las condiciones de vaciar los archivos.';tr = 'Dosyaları temizleme şartları doldurulmalıdır.';it = 'Compilare le condizioni di pulizia del file.';de = 'Es ist notwendig, die Bedingungen für die Reinigung der Dateien auszufüllen.'"),,, "DateTypeAttribute");
		Return;
	EndIf;
	
	ResultingStructure = New Structure();
	ResultingStructure.Insert("IntervalException", IntervalException);
	ResultingStructure.Insert("DateTypeAttribute", DateTypeAttribute);
	
	NotifyChoice(ResultingStructure);

EndProcedure

#EndRegion