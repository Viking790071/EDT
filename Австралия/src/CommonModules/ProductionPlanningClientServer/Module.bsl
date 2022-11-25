#Region Public

Function PlanningIntervalStringDataComposition(Period, PlanningInterval) Export
	
	PeriodStr = "";
	
	If PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Day") 
		Or PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Hour") 
		Or PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Minute") Then
		
		PeriodStr = Format(Period, NStr("en = 'DF=''dd MMMM (ddd)'''; ru = 'DF=''dd MMMM (ddd)''';pl = 'DF=''dd MMMM (ddd)''';es_ES = 'DF=''dd MMMM (ddd)''';es_CO = 'DF=''dd MMMM (ddd)''';tr = 'DF=''dd MMMM (ddd)''';it = 'DF=''dd MMMM (ddd)''';de = 'DF=''dd MMMM (ddd)'''"));
		
	ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Week") Then
		
		PeriodStr = Format(BegOfWeek(Period), "DLF=D") + " - " + Format(EndOfWeek(Period), "DLF=D");
		
	ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Month") Then
		
		PeriodStr = Format(Period, NStr("en = 'DF=''MMMM yyyy'''; ru = 'ДФ=''ММММ гггг''';pl = 'DF = ''MMMM yyyy''';es_ES = 'DF=''MMMM yyyy''';es_CO = 'DF=''MMMM yyyy''';tr = 'DF = ''MMMM yyyy''';it = 'DF=''MMMM yyyy''';de = 'DF=''MMMM yyyy'''"));
		
	EndIf;

	Return PeriodStr;
	
EndFunction

Function CheckTableOfRouting(TableOfRouting, Cancel, IsDocument = False, SynonymOfTable = "Operations") Export
	
	If TableOfRouting.Count() Then
		
		If IsDocument Then
			TabularSectionName = "Activities";
		Else
			TabularSectionName = "Operations";
		EndIf;
		
		FirstOperationExists = False;
		
		LastLine = TableOfRouting[TableOfRouting.Count() - 1];
		
		For Each LineOfRouting In TableOfRouting Do
			
			MessageField = "Object."+ TabularSectionName+ "[" + (LineOfRouting.LineNumber - 1) + "].";
			
			// If it is the last line
			If LineOfRouting.ActivityNumber = LastLine.ActivityNumber Then
				
				If LineOfRouting.LineNumber = LastLine.LineNumber Then
					
					// NextActivityNumber should be empty
					If ValueIsFilled(LineOfRouting.NextActivityNumber) And Not IsDocument Then
						
						TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'On the %1 tab, line %2 includes the last operation in the sequence. This operation cannot be followed by another operation. Clear the next operation for this operation.'; ru = 'На вкладке %1 строка %2 включает последнюю операцию в последовательности. За этой операцией не может следовать другая операция. Удалите следующую операцию для этой операции.';pl = 'Na karcie %1, wiersz %2 zawiera ostatnią operację w sekwencji. Po tej operacji nie może nastąpić inna operacja. Wyczyść następną operację dla tej operacji.';es_ES = 'En la pestaña %1, la línea %2 incluye la última operación de la secuencia. Esta operación no puede ser seguida de otra operación. Borre la próxima operación para esta operación.';es_CO = 'En la pestaña %1, la línea %2 incluye la última operación de la secuencia. Esta operación no puede ser seguida de otra operación. Borre la próxima operación para esta operación.';tr = '%1 sekmesinde %2 satırı sıradaki son işlemi içeriyor. Bu işlemden sonra başka işlem gelemez. Bu işlem için sonraki işlemi silin.';it = 'Nella scheda %1, la riga %2 include l''ultima operazione nella sequenza. Questa operazione non può essere seguita da un''altra operazione. Cancellare la vecchia operazione per questa operazione.';de = 'Auf der Registerkarte %1 enthält die Zeile %2 die letzte Operation in der Sequenz. Auf diese Operation kann keine weitere Operation folgen. Deaktivieren Sie die nächste Operation für diese Operation.'"),
							SynonymOfTable,
							TrimAll(LineOfRouting.LineNumber));
						
						CommonClientServer.MessageToUser(TextMessage,, MessageField + "NextActivityNumber",, Cancel);
						
					EndIf;
					
				Else
					
					// It can be only one last line
					TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'On the %1 tab, operation sequence number %2 is the number of the last operation in the sequence. Check that there is only one operation with this number.'; ru = 'На вкладке %1 порядковый номер операции %2 — это номер последней операции в последовательности. Убедитесь, что это единственная операция с таким номером.';pl = 'Na karcie %1, numer sekwencji operacji %2 jest numerem ostatniej operacji w sekwencji. Sprawdź czy istnieje tylko jedna operacja z tym numerem.';es_ES = 'En la pestaña %1, el número de secuencia de la operación %2 es el número de la última operación de la secuencia. Compruebe que hay sólo una operación con este número.';es_CO = 'En la pestaña %1, el número de secuencia de la operación %2 es el número de la última operación de la secuencia. Compruebe que hay sólo una operación con este número.';tr = '%1 sekmesinde %2 işlem sıra numarası sıradaki son işlemin numarasıdır. Bu numaraya sahip tek işlem olup olmadığını kontrol edin.';it = 'Nella scheda %1, il numero di sequenza dell''operazione %2 è il numero dell''ultima operazione nella sequenza. Verificare che vi sia solo una operazione con questo numero.';de = 'Auf der Registerkarte %1, ist die Operationssequenznummer %2 die Nummer der letzten Operation in der Sequenz. Überprüfen Sie, dass es nur eine Operation mit dieser Nummer gibt.'"),
						SynonymOfTable,
						TrimAll(LineOfRouting.ActivityNumber));
					
					CommonClientServer.MessageToUser(TextMessage,, MessageField + "ActivityNumber",, Cancel);
					
				EndIf;
				
			ElsIf Not ValueIsFilled(LineOfRouting.NextActivityNumber) Then
				
				TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'On the %1 tab, in line %2, the next operation is required.'; ru = 'На вкладке %1 в строке %2 требуется указать следующую операцию.';pl = 'Na karcie %1, w wierszu %2, wymagana jest następna operacja.';es_ES = 'En la pestaña %1, en la línea %2, se requiere la siguiente operación.';es_CO = 'En la pestaña %1, en la línea %2, se requiere la siguiente operación.';tr = '%1 sekmesinin %2 satırında sonraki işlem gerekli.';it = 'Nella scheda %1, riga %2, è richiesta la prossima operazione.';de = 'Auf der Registerkarte %1 in der Zeile %2 ist die nächste Operation erforderlich.'"),
					SynonymOfTable,
					TrimAll(LineOfRouting.LineNumber));
				
				CommonClientServer.MessageToUser(TextMessage,, MessageField + "NextActivityNumber",, Cancel);
				
				
			Else
				
				If LineOfRouting.ActivityNumber >= LineOfRouting.NextActivityNumber Then
				
					TextMessage = NStr("en = 'The number in the Next operation field must be greater than the number in the Operation sequence number field.'; ru = 'Число в поле Следующая операция должно быть больше числа в поле Порядковый номер операции.';pl = 'Liczba w polu Następna operacja musi być większa niż liczba w polu numer sekwencji operacji.';es_ES = 'El número en el campo Operación siguiente debe ser mayor que el número en el campo de número de secuencia de Operación.';es_CO = 'El número en el campo Operación siguiente debe ser mayor que el número en el campo de número de secuencia de Operación.';tr = 'Sonraki işlem alanındaki sayı İşlem sıra numarası alanındaki sayıdan büyük olmalıdır.';it = 'Il numero nel campo Prossima operazione deve essere maggiore del numero nel campo Numero di sequenza dell''operazione.';de = 'Die Zahl im Feld ""Nächste Operation"" muss größer sein als die Zahl im Feld ""Operationssequenznummer"".'");
					
					CommonClientServer.MessageToUser(TextMessage,, MessageField + "ActivityNumber",, Cancel);
					
				EndIf;
				
				FilterParameters = New Structure("ActivityNumber", LineOfRouting.NextActivityNumber);
				
				ArrayRows = TableOfRouting.FindRows(FilterParameters);
				
				If ArrayRows.Count() = 0 Then
					
					TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'On the %1 tab, line %2 includes Next operation %3. An operation with this number is missing.
							|Add the operation or edit the operation number.'; 
							|ru = 'На вкладке %1 строка %2 включает Следующую операцию %3. Операция с этим номером отсутствует.
							|Добавьте операцию или измените номер операции.';
							|pl = 'Na karcie %1, wiersz %2 zawiera następną operację %3. Operacja z tym numerem jest pominięta.
							|Dodaj operację lub zmień numer operacji.';
							|es_ES = 'En la pestaña %1, la línea %2 incluye la operación siguiente %3. Falta una operación con este número.
							|Añade la operación o corrige el número de la operación.';
							|es_CO = 'En la pestaña %1, la línea %2 incluye la operación siguiente %3. Falta una operación con este número.
							|Añade la operación o corrige el número de la operación.';
							|tr = '%1 sekmesinde %2 satırı %3 Sonraki işlemi içeriyor. Bu numaraya sahip işlem eksik.
							|İşlemi ekleyin veya işlem numarasını düzeltin.';
							|it = 'Nella scheda %1, la riga %2 include la Operazione successiva %3. Una operazione con questo numero è mancante.
							|Aggiungere l''operazione o modificare il numero dell''operazione.';
							|de = 'Auf der Registerkarte %1 beinhaltet die Zeile %2 die Nächste Operation %3. Eine Operation mit dieser Nummer fehlt.
							|Fügen Sie die Operation hinzu oder bearbeiten Sie die Operationsnummer.'"),
						SynonymOfTable,
						TrimAll(LineOfRouting.LineNumber),
						TrimAll(LineOfRouting.NextActivityNumber));
						
					CommonClientServer.MessageToUser(TextMessage,, MessageField + "NextActivityNumber",, Cancel);
					
				EndIf;
				
			EndIf;
			
			If LineOfRouting.ActivityNumber = 1 Then
				FirstOperationExists = True;
			EndIf;
			
			// Operations must be sorted
			If LineOfRouting.LineNumber > 1 Then
				
				PrevLine = TableOfRouting[LineOfRouting.LineNumber - 2];
				If LineOfRouting.ActivityNumber < PrevLine.ActivityNumber Then
					
					TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Operations are sorted by sequence number. An operation with sequence number %2 cannot take a position above the operation with sequence number %1.'; ru = 'Операции сортируются по порядковому номеру. Операция с порядковым номером %2 не может занимать позицию над операцией с порядковым номером %1.';pl = 'Operacje są sortowane według sekwencji numerów. Operacja z numerem sekwencji %2 nie może zająć pozycji powyższej operacji z numerem sekwencji %1.';es_ES = 'Las operaciones se clasifican por número de secuencia. Una operación con el número de secuencia %2 no puede posicionarse por encima de la operación con el número de secuencia %1.';es_CO = 'Las operaciones se clasifican por número de secuencia. Una operación con el número de secuencia %2 no puede posicionarse por encima de la operación con el número de secuencia %1.';tr = 'İşlemler sıra numarasına göre sıralanıyor. %2 sıra numarasına sahip işlem %1 sıra numarasına sahip işlemden daha yukarıda olamaz.';it = 'Le operazioni sono ordinate per numero di sequenza. Una operazione con numero di sequenza %2 non può prendere una posizione sopra l''operazione con numero di sequenza %1.';de = 'Operationen werden nach Sequenznummer sortiert. Eine Operation mit der Sequenznummer %2 kann keine Position oberhalb der Operation mit der Sequenz Nummer %1 einnehmen.'"),
						TrimAll(LineOfRouting.ActivityNumber),
						TrimAll(PrevLine.ActivityNumber));
					
					CommonClientServer.MessageToUser(TextMessage,, MessageField + "ActivityNumber",, Cancel);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		If Not FirstOperationExists And Not IsDocument Then
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The %1 tab must include an operation with sequence number 1.'; ru = 'На вкладке %1 должна присутствовать операция с порядковым номером 1.';pl = 'Karta %1 musi zawierać operację z numerem sekwencji 1.';es_ES = 'La pestaña %1 debe incluir una operación con número de secuencia 1.';es_CO = 'La pestaña %1 debe incluir una operación con número de secuencia 1.';tr = '%1 sekmesi 1 sıra numarasına sahip bir işlem içermeli.';it = 'La scheda %1 deve includere una operazione con numero di sequenza 1.';de = 'Die Registerkarte %1 muss eine Operation mit der Sequenznummer 1 enthalten.'"),
				SynonymOfTable);
			
			CommonClientServer.MessageToUser(TextMessage,,,, Cancel);
			
		EndIf;
		
	EndIf;
	
EndFunction

Function EndOfPlanningInterval(Period, PlanningInterval, PlanningIntervalDuration = 0, EndOfPeriod = '00010101') Export
	
	If EndOfPeriod = '00010101' Then
		
		Result = Period;
		
		If PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Minute") Then
			
			Result = BegOfMinute(Result) + PlanningIntervalDuration * 60;
			
		ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Hour") Then
			
			Result = EndOfHour(Result) + 1;
			
		ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Day") Then
			
			Result = EndOfDay(Result) + 1;
			
		ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Week") Then
			
			Result = EndOfWeek(Result) + 1;
			
		ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Month") Then
			
			Result = EndOfMonth(Result) + 1;
			
		EndIf;
		
	Else
		
		Result = AlignPlanningInterval(Period, PlanningInterval, PlanningIntervalDuration, EndOfPeriod);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function ErrorTextNothingToPlan(OrdersArray) Export
	
	ProductionOrders = OrdersArray;
	
	If TypeOf(OrdersArray) <> Type("Array") Then
		ProductionOrders = New Array;
		ProductionOrders.Add(OrdersArray);
	EndIf;
	
	StrProductionOrders = "";
	For Each ProductionOrder In ProductionOrders Do
		StrProductionOrders = StrProductionOrders + ProductionOrder + " ";
	EndDo;
	
	ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Nothing to plan for %1 %2'; ru = 'Отсутствуют элементы для планирования %1 %2';pl = 'Nic nie zaplanowano dla %1 %2';es_ES = 'No hay nada que planificar para %1 %2';es_CO = 'No hay nada que planificar para %1 %2';tr = '%1 %2 için planlanacak bir şey yok';it = 'Niente da pianificare per %1 %2';de = 'Nichts zu planen für %1 %2'"),
		?(ProductionOrders.Count() = 1, NStr("en = 'order'; ru = 'заказ';pl = 'zamówienie';es_ES = 'orden';es_CO = 'orden';tr = 'sipariş';it = 'Ordine';de = 'Auftrag'"), NStr("en = 'orders'; ru = 'заказы';pl = 'zamówienia';es_ES = 'por orden';es_CO = 'por orden';tr = 'siparişler';it = 'Ordini';de = 'aufträge'")),
		StrProductionOrders);
	
	Return ErrorText;
	
EndFunction

#EndRegion

#Region Private

Function AlignPlanningInterval(Period, PlanningInterval, PlanningIntervalDuration, Border)
	
	Result = Period;
	
	If PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Minute") Then
		
		Result = BegOfMinute(Result) + (Border - '00010101');
		
	ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Hour") Then
		
		Result = BegOfHour(Result) + (Border - '00010101');
		
	ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Day") Then
		
		Result = BegOfDay(Result) + (Border - '00010101');
		
	ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Week") Then
		
		Result = BegOfWeek(Result) + (Border - '00010101');
		
	ElsIf PlanningInterval = PredefinedValue("Enum.PlanningIntervals.Month") Then
		
		Result = BegOfMonth(Result) + (Border - '00010101');
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion