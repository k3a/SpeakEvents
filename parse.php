<?php

$row = 0;
$totalnum = 0;
if (($handle = fopen("/tmp/PayPal-20120229-1536.csv", "r")) !== FALSE) {
    while (($data = fgetcsv($handle, 1000, ",")) !== FALSE) {
        $num = count($data);
        
		if ($row == 0) { $row=1; continue; }

		$status = strtolower($data[5]);
		$payer = strtolower($data[10]);
		$name = current(explode(" ", $data[3]));
		$email = $data[21];
		$txn = $data[12];
		$item = $data[15];

		if ($item == "SpeakEvents")
		{
			$totalnum++;
			//echo "Name $name | Status $status | Payer $payer | Email $email | Item $item | Txn $txn\n";
		}


		$row++;
    }
    fclose($handle);

	echo "Total: $totalnum\n";
}

