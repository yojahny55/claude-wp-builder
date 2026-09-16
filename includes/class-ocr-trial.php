<?php
/**
 * Trial file for OCR vs PR-Agent comparison.
 * Contains deliberate defects — DELETE after the trial.
 */

function get_user_orders($wpdb) {
    // Defect 1: unsanitized input into SQL (SQL injection)
    $user_id = $_GET['user_id'];
    $results = $wpdb->get_results("SELECT * FROM wp_orders WHERE user_id = $user_id");

    // Defect 2: unchecked array access on possibly-empty result (NPE-class)
    $first = $results[0];
    $total = $first->total;

    // Defect 3: XSS — echoing raw request parameter
    echo "<div class='order-header'>Orders for: " . $_GET['name'] . "</div>";

    // Defect 4: loose comparison bug — '0e123' == 0 is true in PHP
    $status = $_GET['status'] ?? '0';
    if ($status == 0) {
        $total = 0;
    }

    return $total;
}

function render_order_table($orders) {
    $html = '<table>';
    foreach ($orders as $order) {
        // Defect 5: undefined property access without isset()
        $html .= '<tr><td>' . $order->order_id . '</td><td>' . $order->notes . '</td></tr>';
    }
    $html .= '</table>';
    return $html;
}
